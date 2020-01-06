	processor 16f876
	include <p16f876.inc>
	; https://www.tme.eu/Document/c3972e2483251b2e1f702409912d1888/pic16f87x.pdf
	; ustawienia procesora   
	__config _FOSC_HS & _WDT_OFF & _PWRTE_OFF & _CP_OFF & _BOREN_OFF & _LVP_OFF & _CPD_OFF & _WRT_OFF 
	radix dec	; (!)
	; kody ascii
	; <48....57> 0..9
	; <65....90> A..Z
	; <97...122> a..z
		
XTAL_REQ    equ	    8000000
BAUD_9600   equ	    XTAL_REQ/(16*9600)-1	    ; 51		
   
DIGIT_LED   equ	    RB0   
ALPHA_LED   equ	    RB1      
OTHER_LED   equ	    RB2      
   
	; blok danych w bank 0, wolne mamy od 0x20
	cblock 0x020 
tempByte : 1	; znaczek tymczasowy	
delCntr1 : 1	; programowy licznik	
delCntr2 : 1	; i kolejny	 
	
asciiMin : 1	; zmienne procedurek badających zakres
asciiMax : 1    ; wejściowego kodu ASCII
	endc	    
	
reset_vector:	code 0x0000
	goto main
	;-------------------------------------------			
application:	code	
main:
    	bsf STATUS, RP0	    ; bank 1
	movlw 0x00
	movwf TRISB	    ; port B na out
	
	call initUart
mainLoop:
	call getChar   
	movwf tempByte	    ; na bok
	
	; zgas poprzednie stany ledów
	movlw 0x00
	movwf PORTB
	
	; badamy kolejno - czy cyfry
	movlw "0"
	movwf asciiMin
	movlw "9"
	movwf asciiMax
	call  isCharInRange ; sprawdzenie <min,max>
	bz indicateDigit
	; jak nie, to czy dolne literki
	movlw "a"
	movwf asciiMin
	movlw "z"
	movwf asciiMax
	call isCharInRange ; sprawdzenie <min,max>
	bz indicateAlpha
	; a duże litery?
	movlw "A"
	movwf asciiMin
	movlw "Z"
	movwf asciiMax
	call isCharInRange ; sprawdzenie <min,max>
	bz indicateAlpha
	; no to nie wiem, czerwony OTHER led
	bsf PORTB, OTHER_LED
main_sendBack:
	; odeslij znaczek
	movfw tempByte 
	call putChar	
	goto mainLoop	; while ( 1 )
	; a tu zaczyna się spagetti	
indicateDigit:	
	bsf PORTB, DIGIT_LED    
	goto main_sendBack
indicateAlpha:	
	bsf PORTB, ALPHA_LED
	goto main_sendBack
	;------------------------------------------
	; procedurka korzysta z globali asciiMin,asciiMax i tempByte
	; dwie pierwsze są niszczone, tempByte niezmienny
isCharInRange:
	movfw  asciiMin
        subwf  tempByte,W     
	bc isCharInRange_gteq_min
	; skasuj Z, znaczek poniżej zakresu
	clrz
	return
isCharInRange_gteq_min:
    	; to teraz czy < max+1
    	movfw  asciiMax
	addlw  1	; +1  aby domknąć przedział
        subwf  tempByte,W     
	bnc isCharInRange_lt_max
	; skasuj Z, znaczek powyżej zakresu max
	clrz
	return
isCharInRange_lt_max:
	setz		; znaczek w domknietym przedziale
	return          ; wychodzimy z Z := 1
	
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

