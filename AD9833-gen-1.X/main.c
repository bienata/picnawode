/*
 * File:   main.c
 * Author: otoja
 *
 * Created on 6 lutego 2020, 20:59
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

void delay ( void ) {
    unsigned short a = 0xffff;
    unsigned char b = 0;
    while ( a-- ) {
        b++;
    }
}

void main(void) {
    unsigned char potValue = 0;
    unsigned long freq = AD_FREQ_CALC( 1000.0 );    
    
    TRISB = 0;      // wsio out
   
    RB4 = 1;    // CS, MCP
    RB3 = 1;    // FSYNC, AD
    RB2 = 0;    // LED
    
    spiInit();

    // tak napisali w :
    // https://www.analog.com/media/en/technical-documentation/application-notes/AN-1070.pdf?doc=AD9833.pdf
    spiWrite16 ( 0x2100 , &selectAD9833 );
    spiWrite16 ( FREQ_0_LO ( freq ), &selectAD9833 );    
    spiWrite16 ( FREQ_0_HI ( freq ), &selectAD9833 );        
    spiWrite16 ( 0xC000 , &selectAD9833 );
    spiWrite16 ( 0x2000 , &selectAD9833 );

    while ( 1 ) {
        RB2 ^= true;
        delay();  
        spiWrite16 ( POT_0_COMMAND | potValue , &selectMCP41010 );    
        potValue += 0x10;
    }    
}
