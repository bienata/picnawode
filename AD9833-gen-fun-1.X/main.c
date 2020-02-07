/*
 * File:   main.c
 * Author: otoja
 *
 * Created on 7 lutego 2020, 05:22
 */

#define _XTAL_FREQ 8000000

#include <xc.h>
#include <stdbool.h>
#include <pic16f876.h>

#pragma config FOSC = HS        
#pragma config WDTE = OFF       
#pragma config PWRTE = OFF      
#pragma config BOREN = ON       
#pragma config LVP = OFF        
#pragma config CPD = OFF        
#pragma config WRT = OFF        
#pragma config CP = OFF         

// na motywach 
// https://github.com/tuomasnylund/function-gen/blob/master/code/ad9833.c
#define AD_F_MCLK 25000000      // zegar na plytce z AD9833
#define AD_2POW28 268435456 
#define AD_FREQ_CALC(freq) (unsigned long)(((double)AD_2POW28/(double)AD_F_MCLK*freq)*4)

#define FREQ_0_LO(freq)    ( 0x4000 | ( 0x3FFF & (unsigned short)( freq >> 2 ) ) )
#define FREQ_0_HI(freq)    ( 0x4000 | ( 0x3FFF & (unsigned short)( freq >> 16 ) ) )

// FIGURE 5-2 http://ww1.microchip.com/downloads/en/devicedoc/11195c.pdf 
#define POT_0_COMMAND   0x1100      

typedef void (*TChipSelectFoo)(bool state);

// wybieranie AD9833, FSYNC -->  RB3
void selectAD9833 (bool state) {
    RB3 = state;    
}

// wybieranie MCP41010, CS -->  RB4
void selectMCP41010 (bool state) {
    RB4 = state;    
}

// zapis słowa via SPI, machanie CS-em oddelegowane na zewnątrz
void spiWrite16 ( unsigned short aWord , TChipSelectFoo chipSelector ) {
    unsigned char msb = (( aWord >> 8 ) & 0x00FF );
	unsigned char lsb = ( aWord & 0x00FF );			
    chipSelector( false );      
	SSPBUF = msb;    
	while( BF == 1 );
	SSPBUF = lsb;    
    while( BF == 1 );
    chipSelector( true );  
}

void spiInit ( void ) {
    TRISC5 = 0;     // SDO, out
    TRISC4 = 1;     // SDI, in
    TRISC3 = 0;     // SCK, out     
	SSPEN = 0;
	SMP = 0;
	CKE = 1;
	CKP = 1;
	SSPM0 = 0;
	SSPM1 = 0;
	SSPM2 = 0;
	SSPM3 = 0;
	SSPEN = 1;
}

void putch( char data ){          
    TXREG = data;
    while( TRMT == 0 );
}

unsigned char getch( void ){                          
    while( RCIF == 0 );
    return RCREG;
}

void serialInit( void ) {
    SPBRG = 51; //9600 @ 8MHz
    TXEN = 1; // nadajnik on
    BRGH = 1; // baudy na high
    SPEN = 1; // serial on
    CREN = 1; // cont.rec. on    
}

void setFreq (double f) {
    unsigned long regFreq = AD_FREQ_CALC( f );                
    spiWrite16 ( 0x2100 , &selectAD9833 );
    spiWrite16 ( FREQ_0_LO ( regFreq ), &selectAD9833 );    
    spiWrite16 ( FREQ_0_HI ( regFreq ), &selectAD9833 );                    
}

void main(void) {
    char c = 0;
    char lastMode = 0;
    int potValue = 10;  // tyci-tyci
    double freq = 1000.0;
    
    TRISB = 0;      // wsio out
   
    RB4 = 1;    // CS, MCP
    RB3 = 1;    // FSYNC, AD
    RB2 = 0;    // LED
    
    spiInit();
    serialInit();    

    // tak napisali w :
    // https://www.analog.com/media/en/technical-documentation/application-notes/AN-1070.pdf?doc=AD9833.pdf
    setFreq ( freq );    
    spiWrite16 ( 0xC000 , &selectAD9833 ); //faza
    spiWrite16 ( 0x2000 , &selectAD9833 );

    lastMode = 's'; // sinus
    while ( 1 ) {
        RB2 ^= true;
        c = getch();
        if ( ( c == '-' )||( c == '2' )) {
            potValue--; 
            if ( potValue < 0 ) {
                potValue = 0;
            }
            spiWrite16 ( POT_0_COMMAND | (unsigned char)potValue , &selectMCP41010 );    
        }
        if (( c == '+' )||( c == '8' )) {
            potValue++; 
            if ( potValue > 0xFF ) {
                potValue = 0xFF;
            }
            spiWrite16 ( POT_0_COMMAND | (unsigned char)potValue , &selectMCP41010 );                
        }
        if ( c == '4' ) {
            freq -= 100;
            if ( freq < 100 ) {
                freq = 100;
            }
            setFreq ( freq );       
            c = lastMode;
        }
        
        if ( c == '6' ) {
            freq += 100;
            if ( freq > 5000 ) {
                freq = 5000;
            }
            setFreq ( freq );            
            c = lastMode;            
        }
        if ( c == 't' ) {
            lastMode = c;
            // OPBITEN = 0, MODE = 1, SLEEP12 = 0, SLEEP1 = 0
            spiWrite16 ( 0x0002 , &selectAD9833 );                
        }
        if ( c == 's' ) {
            lastMode = c;            
            // OPBITEN = 0, MODE = 0, SLEEP12 = 0, SLEEP1 = 0
            spiWrite16 ( 0x0000 , &selectAD9833 );                
        }
        if ( c == 'p' ) {
            lastMode = c;            
            // OPBITEN = 1, DIV2 = 1, MODE = 0, SLEEP12 = 0, SLEEP1 = 0
            spiWrite16 ( 0x0028 , &selectAD9833 );                            
        }
        
        putch( c );
    }    
}
