	processor 16f876
	include <p16f876.inc>
	; https://www.tme.eu/Document/c3972e2483251b2e1f702409912d1888/pic16f87x.pdf
	; ustawienia procesora   
	__config _FOSC_HS & _WDT_OFF & _PWRTE_OFF & _CP_OFF & _BOREN_OFF & _LVP_OFF & _CPD_OFF & _WRT_OFF 
	radix dec	; (!)
	
XTAL_REQ    equ	    8000000
BAUD_9600   equ	    XTAL_REQ/(16*9600)-1	    ; 51		
   
	; blok danych w bank 0, wolne mamy od 0x20
	cblock 0x020 
tempByte : 1	; znaczek tymczasowy	
delCntr1 : 1	; programowy licznik	
delCntr2 : 1	; i kolejny	    
	endc	    
	
reset_vector:	code 0x0000
	goto main
	;-------------------------------------------			
application:	code	
main:
	call initUart
mainLoop:
	call getChar   
	movwf tempByte
	xorlw 0x0D	    ; czy == CR?
	btfsc  STATUS, Z
	call sendExtraLF    ; wtedy dodaj LF-a
	movfw tempByte 
	call putChar
	goto mainLoop	
	;-------------------------------------------
	; dosłanie LF-a na terminal
sendExtraLF:
	movlw 0x0A
	call putChar
	return
	;-------------------------------------------				
	; blokujące wysłanie znaczka z W
putChar:
	bcf STATUS,RP0	; bank 0	
	movwf TXREG	
	bsf STATUS,RP0	; bank 1		
putChar_wait:
	btfss TXSTA, TRMT ; while ( TXSTA.TRMT != 1 )
	goto putChar_wait 
	bcf STATUS,RP0	; bank 0		
	return
	;-------------------------------------------					
	; blokujące odbieranie znaczka do W
getChar:
	bcf STATUS,RP0	;   bank 0		    
getChar_wait:    
	btfss PIR1,RCIF         ; while ( PIR1.RCIF != 1)
        goto getChar_wait
        movf RCREG,W            ; save received data in W
        return	
	;-------------------------------------------					
	; setup portu szeregowego
initUart:	
	bsf STATUS, RP0	    ; bank 1

	movlw BAUD_9600	    ; szybkość transmisji
	movwf SPBRG 
	
	; włącz nadajnik generator, na highspeed, reszta bitów 0 co daje
	; transmisje 8bit, asynchroniczną
	movlw (1<<TXEN)|(1<<BRGH)   	
	movwf TXSTA 

	bcf STATUS, RP0	    ; bank 0

	movlw (1<<SPEN)|(1<<CREN); włącz UART
	movwf RCSTA 
    	
	; to do zastanowienia czy z sensem
	call delay	
	; ślepe odczyty zaległości z fifo
	movf RCREG,W	
	movf RCREG,W
	movf RCREG,W	
	return	
	;-------------------------------------------						
delay:
	movlw 0xFF
	movwf delCntr1
delay_1:; petelka zewnetrzna (dekrementuje cntr1)	
	movlw 0xFF		
	movwf delCntr2
delay_2:; petelka wewnetrzna (dec na cntr2)
	nop
	decfsz delCntr2,f	; delCntr2--
	goto delay_2		; while (delCntr2 != 0)
	decfsz delCntr1,f	; delCntr1--
	goto delay_1		; while (delCntr1 != 0)
        return 	
	
	end

