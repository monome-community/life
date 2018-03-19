// press p to pause

0 => int DEAD;
1 => int ALIVE;

-1 => int DEATH;
0  => int NO_CHANGE;
1  => int BIRTH;

0 => int OFF;
1 => int ON;

0 => int DISPLAY;
1 => int DELTA;

0 => int BUTTON_UP;
1 => int BUTTON_DOWN;

// osc setup

"/life" => string prefix; 

//initial send and receive
OscSend xmit;
xmit.setHost("localhost", 12002);

OscRecv recv;
8000 => recv.port;
recv.listen ();

//list devices
xmit.startMsg("/serialosc/list", "si");
"localhost" => xmit.addString;
8000 => xmit.addInt;

<<<"looking for a monome...", "">>>;

recv.event("/serialosc/device", "ssi") @=> OscEvent discover;
discover => now;

string serial; string devicetype; int port;

while(discover.nextMsg() != 0) {
    discover.getString() => serial;
    discover.getString() => devicetype;
    discover.getInt() => port;
    
    <<<"found", devicetype, "(", serial, ") on port", port>>>;
}

//connect to device 
xmit.setHost("localhost", port);
xmit.startMsg("/sys/port", "i");
8000 => xmit.addInt;

//get size
recv.event("/sys/size", "ii") @=> OscEvent getsize;

xmit.startMsg("/sys/info", "si");
"localhost" => xmit.addString;	
8000 => xmit.addInt;

getsize => now;

int width; int height;

while(getsize.nextMsg() != 0) {
    getsize.getInt() => width;
    getsize.getInt() => height;
    
    //	<<<"size is", width, "by", height>>>;
}

// patch
//Blit s => ADSR e => JCRev r => dac;
//e.set( 0.5::ms, 0.5::ms, 0.5, 0.5::ms );
JCRev reverb => dac;
0.02 => reverb.mix;

SinOsc oscillators[width][height];
ADSR envelopes[width][height];
int x,y;
for(0 => x; x < width; x++) {
    for(0 => y; y < height; y++) {
        oscillators[x][y] @=> SinOsc oscillator;
        Std.mtof(40 + (y*10) + (x*2)) => oscillator.freq;
        0.05 => oscillator.gain;
        envelopes[x][y] @=> ADSR envelope;
        envelope.set(1::ms, 2000::ms, 0, 20::ms);
        oscillator => envelope => reverb;
    }
}

//set prefix
xmit.startMsg("/sys/prefix", "s");
prefix => xmit.addString;

recv.event( prefix+"/grid/key", "iii") @=> OscEvent oe;

clear_all();

int world[2][width][height];

int state,count,collect,i,rate,change;

float speed;

2000 => rate;
(0.05*rate/1000.0) => speed;

2 => collect;

//pause stuff
KBHit kb; 
int keyboardPause;
int autoPause;
spork ~gridPressListener();
spork ~keyboardListener();

<<<"go!", "">>>;
<<<"press p to pause", "">>>;

while ( true ) {
    /*
    while ( enc.nextMsg() != 0 )
    {
        enc.getInt() => i;	
        enc.getInt() => change;
        
        rate + change => rate;
        if (rate<1000) 1000=>rate;
        //<<< "rate:", rate >>>;
        (0.05*rate/1000.0) => speed;
    }
    */
    
    //clear_all();
    
    for(0 => x; x < width; x++) {
        for(0 => y; y < height; y++) { 
            if (world[DELTA][x][y] == BIRTH) {
                ALIVE => world[DISPLAY][x][y]; 
                led_set(x,y,ON);
                
                //Std.mtof( 50 + (y*10) + (x*2) ) => s.freq;
                //y => s.harmonics;
                //e.keyOn();
                //2::ms => now;
                //e.keyOff();
                envelopes[x][y].keyOn();
            } 
            if (world[DELTA][x][y] == DEATH) {
                DEAD => world[DISPLAY][x][y];  
                led_set(x,y,OFF);
                envelopes[x][y].keyOff();      	
            }
            
            NO_CHANGE => world[DELTA][x][y]; 
        }
    }
    
    if (keyboardPause == 0 && autoPause == 0) {
        // Birth and death cycle 
        for (0=>x; x < width; x++) { 
            for (0=>y; y < height; y++) {
                neighbors(x, y) => count;
                if (count == 3 && world[DISPLAY][x][y] == DEAD) 
                    BIRTH => world[DELTA][x][y]; 
                if ((count < 2 || count > 3) && world[DISPLAY][x][y] == ALIVE) 
                    DEATH => world[DELTA][x][y];
            } 
        } 
    }
    
    speed::second => now;
}

fun void gridPressListener()
{
    int numFingersDown;
    while(true) {
        oe => now;
        while ( oe.nextMsg() != 0 ) {
            oe.getInt() => x;	
            oe.getInt() => y;
            oe.getInt() => state;
                
            if (x < width && y < height) {
                if (keyboardPause) {
                    if (state == BUTTON_DOWN) {
                        if (world[DISPLAY][x][y] == DEAD) {
                            BIRTH => world[DELTA][x][y];
                        } else {
                            DEATH => world[DELTA][x][y];
                        }
                    }
                } else {
                    if (state == BUTTON_DOWN) {
                        1 => autoPause;
                        numFingersDown++;
                        if (world[DISPLAY][x][y] == DEAD) {
                            BIRTH => world[DELTA][x][y];
                        } else {
                            DEATH => world[DELTA][x][y];
                        }
                    } else {
                        numFingersDown--;
                        if (numFingersDown == 0) {
                            0 => autoPause;
                        }
                    }
                }
            }
        }
    }
}

fun void keyboardListener()
{
    while(true) {
        kb => now;
        while( kb.more() ){
            kb.getchar() => int char;
            //<<<"ascii", char>>>;
            if (char == 112){ // p
                Std.abs (1 - keyboardPause ) => keyboardPause;
                if (keyboardPause == 1){<<<"p a u s e", "">>>;}
                if (keyboardPause == 0){<<<"go", "">>>;}
			}
		}
	}
}

// Add error checking in here somewhere.
fun void led_set(int x,int y,int s)
{
	xmit.startMsg("/life/grid/led/set", "iii");
	x => xmit.addInt;
	y => xmit.addInt;
	s => xmit.addInt;
}

fun void clear_all()
{
	xmit.startMsg("/life/grid/led/all", "i");
	0 => xmit.addInt;
}

// Count the number of adjacent cells 'on' 
fun int neighbors(int x, int y) 
{ 
  return world[DISPLAY][(x + 1) % width][y] + 
         world[DISPLAY][x][(y + 1) % height] + 
         world[DISPLAY][(x + width - 1) % width][y] + 
         world[DISPLAY][x][(y + height - 1) % height] + 
         world[DISPLAY][(x + 1) % width][(y + 1) % height] + 
         world[DISPLAY][(x + width - 1) % width][(y + 1) % height] + 
         world[DISPLAY][(x + width - 1) % width][(y + height - 1) % height] + 
         world[DISPLAY][(x + 1) % width][(y + height - 1) % height]; 
} 
