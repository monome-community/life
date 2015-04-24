// patch
Blit s => ADSR e => JCRev r => dac;
.5 => s.gain;
.01 => r.mix;

// set adsr
e.set( 0.5::ms, 0.5::ms, .5, 0.5::ms );

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

	while(discover.nextMsg() != 0){

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

	while(getsize.nextMsg() != 0){

		getsize.getInt() => width;
		getsize.getInt() => height;

	//	<<<"size is", width, "by", height>>>;
	}

	//set prefix
	xmit.startMsg("/sys/prefix", "s");
	prefix => xmit.addString;

    	recv.event( prefix+"/grid/key", "iii") @=> OscEvent oe;

clear_all();

int world[width][height][2];

int x,y,state,count,collect,i,rate,change;

float speed;

1000 => rate;
(0.05*rate/1000.0) => speed;

0 => i;
2 => collect;

<<<"go!", "">>>;

while ( true ) 
{
	(i+ 1) % collect => i;
	if (i == 0)
	while ( oe.nextMsg() != 0 )
	{
		oe.getInt() => x;	
		oe.getInt() => y;
		oe.getInt() => state;

		if (state == 1 && x < width && y < height) {
			1 => world[x][y][1];
		}
	}

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

	for(0 => x; x < width; x++)
  	for(0 => y; y < height; y++) { 
		if (world[x][y][1] == 1 ) {
    	   	1 => world[x][y][0]; 
        	led_set(x,y,1);

		    Std.mtof( 50 + (y*10) + (x*2) ) => s.freq;
			y => s.harmonics;
		    e.keyOn();
    		2::ms => now;
    		e.keyOff();
        } 
      	if (world[x][y][1] == -1) {
  			0 => world[x][y][0];  
			led_set(x,y,0);      	
		}

		0 => world[x][y][1]; 
	}

	// Birth and death cycle 
	for (0=>x; x < width; x++) { 
    	for (0=>y; y < height; y++) { 
      		neighbors(x, y) => count; 
      		if (count == 3 && world[x][y][0] == 0) 
      			1 => world[x][y][1]; 
      		if ((count < 2 || count > 3) && world[x][y][0] == 1) 
     		 	-1 => world[x][y][1];    
    	} 
  	} 

	speed::second => now;


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
  return world[(x + 1) % width][y][0] + 
         world[x][(y + 1) % height][0] + 
         world[(x + width - 1) % width][y][0] + 
         world[x][(y + height - 1) % height][0] + 
         world[(x + 1) % width][(y + 1) % height][0] + 
         world[(x + width - 1) % width][(y + 1) % height][0] + 
         world[(x + width - 1) % width][(y + height - 1) % height][0] + 
         world[(x + 1) % width][(y + height - 1) % height][0]; 
} 
