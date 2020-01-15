	processor 16f876
	include <p16f876.inc>	
	include "chargen.inc"	    ; <--- definicje znaczków
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

MODULES_NO	    equ	    3
SCREEN_SIZE	    equ	    MODULES_NO*8 
	    
	    ; ustawia rejest kostki dla zadanej ilości w łańcuchu
@setMAX7219reg  macro   register, value, how_many_modules
	    variable n
n = 0
	    bcf PORTB, MAX7219_CS			    
	    while n < how_many_modules
		movlw register
		call writeSPI	    
		movlw value
		call writeSPI	    	    
n = n + 1	; kolejny modułek
	    endw
	    bsf PORTB, MAX7219_CS			    
	    endm
		     
	; blok danych w bank 0, wolne mamy od 0x20
	cblock 0x020 
bannerHiPtr : 1	
bannerLoPtr : 1		
bannerItemCntr : 1
	
delCntr1 : 1	; programowy licznik	
delCntr2 : 1	; i kolejny	
	
	; bufor ekranowy
itemCntr : 1		
screenCurrentLine : 1 
moduleCntr : 1 	

screenBuff : SCREEN_SIZE    ; moduły*8
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
	@setMAX7219reg MAX7219_DisplayTest, 0, MODULES_NO
	; bez dekodowania, mapowanie 1:1
	@setMAX7219reg MAX7219_DecodeMode, 0, MODULES_NO	
	; jasność niewielka (0..7)
	@setMAX7219reg MAX7219_Intensity, 1, MODULES_NO
	; obsługuj wszystkie linie (0..7)
	@setMAX7219reg MAX7219_ScanLimit, 7, MODULES_NO
	; włącz sterownik (0/1)
	@setMAX7219reg MAX7219_Shutdown, 1, MODULES_NO
	
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
	clrf screenCurrentLine	; od zerowej
updateDisplay_nextLine:	    ; iteracja po liniach modułu 0-1   
	call updateSelectedLine    ; odświeża wybraną linijke w modłach, ile by ich nie było
	incf screenCurrentLine	; screenCurrentLine++
	movlw 8
	subwf screenCurrentLine,W   ; screenCurrentLine == 8
	bnz updateDisplay_nextLine  ; kolejna
	return
	
	; w screenCurrentLine bieżąca linijka
	; trzeba ją wysłać tyle razy ile modułów
updateSelectedLine:	
	clrf moduleCntr	    ; licznik modulów na 0
	movlw screenBuff	
	movwf FSR	; wskaźnik na początek ekranu
	movfw screenCurrentLine
	addwf FSR	; nalóż offset (linijkę)
	; rozpocznij transakcje SPI
	bcf PORTB, MAX7219_CS			    	
updateSelectedLine_nextModule:
	; dla każdego wskazanego modulu wyslij:
	; a) numer linii (powiększony o 1
	movfw screenCurrentLine
	incf screenCurrentLine,W    ; W := linijka + 1
	call writeSPI
	; b) daną spod adresu FSR 
	movfw INDF
	call writeSPI
	; przelicz FSR-a czyli (baza + linijka) + modul * 8
	movlw 8
	addwf FSR	; FSR := FSR + 8	
	incf moduleCntr
	movlw MODULES_NO	    ; <--- liczba modulów
	subwf moduleCntr,W   ; czy istatni?
	bnz updateSelectedLine_nextModule ; jak nie - kontynuuj
	; zakończ transakcje SPI
	bsf PORTB, MAX7219_CS			    	
	return
	
	; przepisuje paski N na N+1		
	; wersja dla ludzi 
scrollBuffer:
	movlw SCREEN_SIZE-1	;
	movwf itemCntr ; bo przekładamy size-1 elementów
	movlw screenBuff+SCREEN_SIZE-2	; zacznij od przed,przed ostatniego elementu
	movwf FSR	; wskaźnik prawie na koniec ekranu (-2)
scrollBuffer_moveNext:
	; przesun elementy N na N+1
	movfw INDF	; W := *ptr
	incf FSR	; ptr++
	movwf INDF	; *ptr := W
	movlw 2
	subwf FSR	; ustaw ptr na kolejny
	decf itemCntr	
	bnz scrollBuffer_moveNext   ; while ( itemCntr != 0 )
	return
	
	; przepisuje paski N na N+1	
	; wersja z cyklu #JPDL
@moveScreenbyte	macro src
    	movfw screenBuff+src
	movwf screenBuff+src+1
		endm	
scrollBuffer_OLD:
	@moveScreenbyte 22
	@moveScreenbyte 21
	@moveScreenbyte 20
	@moveScreenbyte 19
	@moveScreenbyte 18
	@moveScreenbyte 17
	@moveScreenbyte 16
	@moveScreenbyte 15
	@moveScreenbyte 14
    	@moveScreenbyte 13
	@moveScreenbyte 12
	@moveScreenbyte 11
	@moveScreenbyte 10
	@moveScreenbyte 9
	@moveScreenbyte 8
	@moveScreenbyte 7
	@moveScreenbyte 6
	@moveScreenbyte 5
	@moveScreenbyte 4
	@moveScreenbyte 3
	@moveScreenbyte 2
	@moveScreenbyte 1
	@moveScreenbyte 0
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
	movlw 0xAF
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
	@CHAR_H
	@CHAR_E
	@CHAR_L
	@CHAR_L
	@CHAR_O
    	@CHAR_SPACE
	@CHAR_SPACE	
	@CHAR_M
	@CHAR_I
	@CHAR_C
	@CHAR_R
	@CHAR_O
	@CHAR_G
	@CHAR_E
	@CHAR_E
	@CHAR_K
	@CHAR_SPACE
	@CHAR_SPACE
	@CHAR_M
	@CHAR_A
	@CHAR_X
	@CHAR_7
	@CHAR_2
	@CHAR_1
	@CHAR_9
	@CHAR_SPACE
	@CHAR_D
	@CHAR_E
	@CHAR_M
	@CHAR_O
	@CHAR_SPACE	
	@CHAR_SPACE	
BANNER_DATA_END:	    
    
	end

