	processor 16f876
	include <p16f876.inc>	
	; PIC16F876 https://www.tme.eu/Document/c3972e2483251b2e1f702409912d1888/pic16f87x.pdf
	; MAX7219 https://datasheets.maximintegrated.com/en/ds/MAX7219-MAX7221.pdf 
	; ustawienia procesora   
	__config _FOSC_HS & _WDT_OFF & _PWRTE_OFF & _CP_OFF & _BOREN_OFF & _LVP_OFF & _CPD_OFF & _WRT_OFF 
	radix dec	; (!)
		
XTAL_FREQ    equ    8000000
MAX7219_CS  equ	    RB3		; inicjalnie na H

MAX7219_DecodeMode  equ	    0x09  
MAX7219_Intensity   equ	    0x0A
MAX7219_ScanLimit   equ	    0x0B
MAX7219_Shutdown    equ	    0x0C  
MAX7219_DisplayTest equ	    0x0F    
    
setMAX7219reg  macro   register, value
	    bcf PORTB, MAX7219_CS		
	    movlw register
	    call writeSPI	    
	    movlw value
	    call writeSPI	    
	    bsf PORTB, MAX7219_CS		
	    endm
	    
  
	; blok danych w bank 0, wolne mamy od 0x20
	cblock 0x020 
delCntr1 : 1	; programowy licznik	
delCntr2 : 1	; i kolejny	 	
	endc	    
	
reset_vector:	code 0x0000
	goto main
	;-------------------------------------------			
application:	code	
main:
	banksel TRISB	
	clrf TRISB	    ; port B na out
	; piny SPI, czytaj 9.3.3 ENABLING SPI I/O
	bcf TRISC, RC5	    ; RC.5 (SPI SDO)
	bsf TRISC, RC4	    ; RC.4 (SPI SDI), nie korzystam, ale...
	bcf TRISC, RC3	    ; RC.3 (SPI SCK)		
	; SPI
	movlw (1<<SMP)|(1<<CKE)
	movwf SSPSTAT
	
	banksel SSPCON	
	movlw (1<<SSPEN)|0x00
	movwf SSPCON	    ; domyślne
	
	; /CS MAX-a na H
	bsf PORTB, MAX7219_CS

	; normalna praca (0) a nie test lampek (1)
	setMAX7219reg MAX7219_DisplayTest, 0
	; bez dekodowania, mapowanie 1:1
	setMAX7219reg MAX7219_DecodeMode, 0	
	; jasność niewielka (0..7)
	setMAX7219reg MAX7219_Intensity, 1
	; obsługuj wszystkie linie (0..7)
	setMAX7219reg MAX7219_ScanLimit, 7
	; włącz sterownik (0/1)
	setMAX7219reg MAX7219_Shutdown, 1
	
loop:	
	setMAX7219reg 1, b'11111111'
	setMAX7219reg 2, b'10000001'	
	setMAX7219reg 3, b'10000001'
	setMAX7219reg 4, b'10000001'	
	setMAX7219reg 5, b'10000001'
	setMAX7219reg 6, b'10000001'	
	setMAX7219reg 7, b'10000001'
	setMAX7219reg 8, b'11111111'	
	
	call delay

	setMAX7219reg 1, b'00000000'
	setMAX7219reg 2, b'01111110'	
	setMAX7219reg 3, b'01000010'
	setMAX7219reg 4, b'01000010'	
	setMAX7219reg 5, b'01000010'
	setMAX7219reg 6, b'01000010'	
	setMAX7219reg 7, b'01111110'
	setMAX7219reg 8, b'00000000'	
	
	call delay

	setMAX7219reg 1, b'00000000'
	setMAX7219reg 2, b'00000000'	
	setMAX7219reg 3, b'00111100'
	setMAX7219reg 4, b'00100100'	
	setMAX7219reg 5, b'00100100'
	setMAX7219reg 6, b'00111100'	
	setMAX7219reg 7, b'00000000'
	setMAX7219reg 8, b'00000000'	

	call delay

	setMAX7219reg 1, b'00000000'
	setMAX7219reg 2, b'00000000'	
	setMAX7219reg 3, b'00000000'
	setMAX7219reg 4, b'00011000'	
	setMAX7219reg 5, b'00011000'
	setMAX7219reg 6, b'00000000'	
	setMAX7219reg 7, b'00000000'
	setMAX7219reg 8, b'00000000'	

	call delay
	
	goto loop
	
	; nadaje bajta z W i czeka aż wyśle
writeSPI:
	movwf SSPBUF	
	bsf STATUS, RP0	    ; bank 1			
writeSPI_wait:
	btfss SSPSTAT, BF    ; skonczyleś transmisje?
	goto writeSPI_wait  ; neee
	bcf STATUS, RP0	    ; bank 0				
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

