    processor 16f876
    include <p16f876.inc>
    ; https://www.tme.eu/Document/c3972e2483251b2e1f702409912d1888/pic16f87x.pdf
    ; ustawienia procesora   
    __config _FOSC_HS & _WDT_OFF & _PWRTE_OFF & _CP_OFF & _BOREN_OFF & _LVP_OFF & _CPD_OFF & _WRT_OFF & _DEBUG_ON 
    
LED_1		equ 0	    ; RB.0 bicik portu z ledem
LED_2		equ 1	    ; RB.1 drugi led

;-------------------------------------------	

		; blok danych w bank 0, wolne mamy od 0x20
		cblock 0x020 
delCntr1 : 1	; programowy licznik	
delCntr2 : 1	; i kolejny
		endc

		;-------------------------------------------		

reset_vector:	code 0x0000
		goto main

		;-------------------------------------------	
		
application:	code	
main:
		; init rupieci
		; STATUS jest mapowany na wszystkie banki!!

		bsf STATUS, RP0 ; bank 1, bo tam konfig portu B TRISB	

		bcf TRISB, LED_1 ; port leda 1 na wyjscie	
		bcf TRISB, LED_2 ; port leda 2

		bcf STATUS, RP0 ; bank 0
		; stan poczatkowy led
		bcf PORTB, LED_1 ; led off
		bcf PORTB, LED_2 ; led off		
mainLoop:	
		bsf PORTB, LED_1    ; swieci, nie swieci
		bcf PORTB, LED_2

		call delay	    ; daj popatrzec
		
		bcf PORTB, LED_1    ; nie swieci, swieci
		bsf PORTB, LED_2

		call delay	    ; daj popatrzec
		
		goto mainLoop

;-------------------------------------------		

delay:
		movlw 0xFF
		movwf delCntr1
delay_1:	; petelka zewnetrzna (dekrementuje cntr1)	
		movlw 0xFF		
		movwf delCntr2
delay_2:	; petelka wewnetrzna (dec na cntr2)
		nop
		decfsz delCntr2,f	; delCntr2--
		goto delay_2		; while (delCntr2 != 0)
		decfsz delCntr1,f	; delCntr1--
		goto delay_1		; while (delCntr1 != 0)
                return 	
		
;-------------------------------------------		
		
		end