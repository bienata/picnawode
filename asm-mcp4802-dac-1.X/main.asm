	processor 16f876
	include <p16f876.inc>	
	; PIC16F876 https://www.tme.eu/Document/c3972e2483251b2e1f702409912d1888/pic16f87x.pdf
	; MCP4802 http://ww1.microchip.com/downloads/en/devicedoc/20002249b.pdf	
	; ustawienia procesora   
	__config _FOSC_HS & _WDT_OFF & _PWRTE_OFF & _CP_OFF & _BOREN_OFF & _LVP_OFF & _CPD_OFF & _WRT_OFF 
	radix dec	; (!)
		
XTAL_REQ    equ	    8000000
   
DIGIT_LED   equ	    RB0   
ALPHA_LED   equ	    RB1      
OTHER_LED   equ	    RB2      

MCP4802_CS  equ	    RB3		; inicjalnie na H
DAC_SHDN    equ  0x10		; bit /SHDN
DAC_CH_A    equ	 0x00		; bit selekcji kanału 
DAC_CH_B    equ	 0x80		; !A / B 
   
	; blok danych w bank 0, wolne mamy od 0x20
	cblock 0x020 
valDacA : 1	; DAC A
valDacB : 1	; DAC B	
valTemp : 1	; schowek
	
sineHiPtr : 1	
sineLoPtr : 1		
sineSampleCntr : 1
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
	movlw (1<<SSPEN)
	movwf SSPCON	    ; domyślne
	
	; /CS DAC-ka na H
	bsf PORTB, MCP4802_CS

	; reset wskaźników
	call initSinePointers
mainLoop:
	call getSineSample  ; probka do W
	movwf valDacA	    ; oba kanały
	movwf valDacB	    ; to samo
	call updateDAC
	incf sineSampleCntr	; cntr++
	movlw 128
	subwf sineSampleCntr, W
	btfsc STATUS, Z		; gdy != 128 
	call initSinePointers	; pomin reset wskaźników
	goto mainLoop	
	
	;-----------------------------------------------------------
	; ustawia kanały A,B ze zmiennych valDacA, valDacA
updateDAC:
	; kanal A
	; transakcja  /CS := L
	bcf PORTB, MCP4802_CS
	; przekładka bitów
	swapf valDacA, W    ; b74<->b30
	movwf valTemp	    ; przełożone na bok, przyda się
	andlw 0x0F	    ; tylko najmłodsze
	iorlw DAC_CH_A|DAC_SHDN ; polecenie DAC /SHDN := 1 dla A
	call writeSPI	    ; MSB (komenda i kawałek danej)
	movfw valTemp	    ; daj po przekładce
	andlw 0xF0	    ; zostaw górny nib, dolne zera
	call writeSPI	    ; LSB (dolny kawałek danej)
	; domknij transakcje SPI /CS := H
	bsf PORTB, MCP4802_CS	
	; kanal B
	; transakcja  /CS := L
	bcf PORTB, MCP4802_CS
	; przekładka bitów
	swapf valDacB, W    ; b74<->b30
	movwf valTemp	    ; przełożone na bok, przyda się
	andlw 0x0F	    ; tylko najmłodsze
	iorlw DAC_CH_B|DAC_SHDN ; polecenie DAC /SHDN := 1 dla B
	call writeSPI	    ; MSB (komenda i kawałek danej)
	movfw valTemp	    ; daj po przekładce
	andlw 0xF0	    ; zostaw górny nib, dolne zera
	call writeSPI	    ; LSB (dolny kawałek danej)
	; domknij transakcje SPI /CS := H
	bsf PORTB, MCP4802_CS	
	return
	
	; nadaje bajta z W i czeka aż wyśle
writeSPI:
	movwf SSPBUF	
	bsf STATUS, RP0	    ; bank 1			
writeSPI_wait:
	btfss SSPSTAT, BF    ; skonczyleś transmisje?
	;BTFSS PIR1,SSPIF
	goto writeSPI_wait  ; neee
	bcf STATUS, RP0	    ; bank 0				
	return

initSinePointers:
	clrf sineSampleCntr 
	movlw high SINE_DATA       
        movwf sineHiPtr           
	movlw low SINE_DATA       
        movwf sineLoPtr           	
	return
	
getSineSample:
	movf sineHiPtr, W          
        movwf PCLATH	    ; górny adres
        movf sineLoPtr, W   ; dolny
        incf sineLoPtr, f   ; ++
        skpnz		    ;
        incf sineHiPtr, f   ; hi++ tylko gdy zawinęła się strona (lo)	
        movwf PCL           ; skok na bungee
SINE_DATA:	
	dt 128,134,140,146,152,158,165,170
	dt 176,182,188,193,198,203,208,213
	dt 218,222,226,230,234,237,240,243
	dt 245,248,250,251,253,254,254,255
	dt 255,255,254,254,253,251,250,248
	dt 245,243,240,237,234,230,226,222
	dt 218,213,208,203,198,193,188,182
	dt 176,170,165,158,152,146,140,134
	dt 128,121,115,109,103,97,90,85
	dt 79,73,67,62,57,52,47,42
	dt 37,33,29,25,21,18,15,12
	dt 10,7,5,4,2,1,1,0
	dt 0,0,1,1,2,4,5,7
	dt 10,12,15,18,21,25,29,33
	dt 37,42,47,52,57,62,67,73
	dt 79,85,90,97,103,109,115,121
	
	end

