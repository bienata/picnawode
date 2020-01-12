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
	
FONT_M	macro
	dt b'01111111'		
	dt b'00100000'		
	dt b'00010000'	
	dt b'00100000'		
	dt b'01111111'	
	dt b'00000000'		
	endm
FONT_I	macro
	dt b'01111111'		
	dt b'00000000'		
	endm
FONT_C	macro
	dt b'01111111'		
	dt b'01000001'		
	dt b'01000001'		
	dt b'00000000'		
	endm
FONT_R	macro
	dt b'01111111'		
	dt b'01001100'		
	dt b'01001010'		
	dt b'00110001'		
	dt b'00000000'		
	endm	
FONT_O	macro
	dt b'01111111'		
	dt b'01000001'		
	dt b'01111111'		
	dt b'00000000'		
	endm
FONT_G	macro
	dt b'00111110'		
	dt b'01000001'		
	dt b'01001001'		
	dt b'00101110'		
    	dt b'00000000'		
	endm
FONT_E	macro	
	dt b'01111111'
	dt b'01001001'	
	dt b'01001001'
	dt b'00000000'	
	endm
FONT_K	macro	
	dt b'01111111'
	dt b'00000100'	
	dt b'00001010'
	dt b'00010001'	
	dt b'00000000'		
	endm
FONT_SPACE macro	
	dt b'00000000'	
	dt b'00000000'		
	dt b'00000000'		
	dt b'00000000'	
	dt b'00000000'		
	dt b'00000000'	
	endm
	    
  
	; blok danych w bank 0, wolne mamy od 0x20
	cblock 0x020 
bannerHiPtr : 1	
bannerLoPtr : 1		
bannerItemCntr : 1
	
delCntr1 : 1	; programowy licznik	
delCntr2 : 1	; i kolejny	
	
	; bufor ekranowy
screenCntr : 1 
screenBuff : 8	
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
	
	call initBannerPointers
loop:	
	call scrollBuffer	; item + 1 := item, miejsce na 1 wpi    
	call getBannerItem
	movwf screenBuff+0	; zapisz 1-szy element
	call updateDisplay	; wyslij na MAX-a
	call delay
	incf bannerItemCntr	; cntr++
	movlw BANNER_DATA_END-BANNER_DATA
	subwf bannerItemCntr, W
	bnz loop		; gdy jeszcze nie koniec
	call initBannerPointers	; reset wskaźników	
	goto loop
	
	; przepisuje obszar screenBuff na matrycę
updateDisplay:
	movlw screenBuff
	movwf FSR	    ; wskaźnik na ekran
	movlw 1
	movwf screenCntr	    ; licznik pasków := 1
updateDisplay_continue:	
	bcf PORTB, MAX7219_CS		
	movfw screenCntr
	call writeSPI		    ; adres paska
	movfw INDF		    ; screenBuffer [ screenCntr ]
	call writeSPI		    ; zawartośc paska
        bsf PORTB, MAX7219_CS		
	incf screenCntr		    ; adres dla MAX ++
	incf FSR		    ; cntr++
	movlw screenBuff+8	    ; czy koniec bufora?
	subwf FSR, W
	bnz updateDisplay_continue
	return

	; przepisuje paski N na N+1
scrollBuffer:
    	movfw screenBuff+6
	movwf screenBuff+7
	    movfw screenBuff+5
	    movwf screenBuff+6
    	movfw screenBuff+4
	movwf screenBuff+5
	    movfw screenBuff+3
	    movwf screenBuff+4
	movfw screenBuff+2
	movwf screenBuff+3
	    movfw screenBuff+1
	    movwf screenBuff+2
	movfw screenBuff+0
	movwf screenBuff+1
	return
	
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

initBannerPointers:
	clrf bannerItemCntr 
	movlw high BANNER_DATA       
        movwf bannerHiPtr           
	movlw low BANNER_DATA       
        movwf bannerLoPtr           	
	return
	
getBannerItem:
	movf bannerHiPtr, W          
        movwf PCLATH	    ; górny adres
        movf bannerLoPtr, W   ; dolny
        incf bannerLoPtr, f   ; ++
        skpnz		    ;
        incf bannerHiPtr, f   ; hi++ tylko gdy zawinęła się strona (lo)	
        movwf PCL           ; skok na bungee
BANNER_DATA:	
	dt b'01111111'
	dt b'00001000'	
	dt b'01111111'
	dt b'00000000'	
	dt b'01111111'
	dt b'01001001'	
	dt b'01001001'
	dt b'00000000'	
	dt b'01111111'
	dt b'00000001'	
	dt b'00000001'
	dt b'00000000'	
	dt b'01111111'
	dt b'00000001'	
	dt b'00000001'
	dt b'00000000'	
	dt b'01111111'
	dt b'01000001'	
	dt b'01111111'
	dt b'00000000'	
	dt b'00000000'		
	dt b'00000000'		
	dt b'00000000'		
	dt b'00000000'	
	FONT_M
	FONT_I
	FONT_C
	FONT_R
	FONT_O
	FONT_G
	FONT_E
	FONT_E
	FONT_K
	FONT_SPACE
	FONT_SPACE	
BANNER_DATA_END:	    
    
	end

