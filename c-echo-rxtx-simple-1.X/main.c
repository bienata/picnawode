/*
 * File:   main.c
 * Author: otoja
 *
 * Created on 6 stycznia 2020, 09:55
 * 
 * ratujące d*** proste echo w C, które na pewno działa
 */

#define _XTAL_FREQ 8000000
#include <xc.h>
#include <pic16f876.h>

#pragma config FOSC = HS        
#pragma config WDTE = OFF       
#pragma config PWRTE = OFF      
#pragma config BOREN = ON       
#pragma config LVP = OFF        
#pragma config CPD = OFF        
#pragma config WRT = OFF        
#pragma config CP = OFF         

void putch( char data ){          
    TXREG = data;
    while( TRMT == 0 );
}

unsigned char getch( void ){                          
    while( RCIF == 0 );
    return RCREG;
}
 
void main( void ) {
    unsigned char c;
    TRISB = 0;  // port out
    PORTB = 0;  // ledy off
    SPBRG = 51; //9600 @ 8MHz
    TXEN=1; // nadajnik on
    BRGH=1; // baudy na high
    SPEN=1; // serial on
    CREN=1; // cont.rec. on
    while( 1 ) {
        c = getch();
        PORTB = c & 0x07; // pokaż, że żyjesz 
        putch ( c );
   }
}