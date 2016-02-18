
#include <Timer.h>
#include "messages.h"
#include <printf.h>

module AppP
{
	uses interface Boot;
	uses interface SplitControl as AMControl;
	uses interface AppInterface;
	uses interface Timer<T32khz> as TimerInitialize;
	uses interface TimeSyncPacket<T32khz, uint32_t> as TSPacket;
	uses interface PacketLink;
	uses interface Random;
	
}
implementation
{
	#define IS_MASTER (TOS_NODE_ID == 1)
	#define SECOND 32768L
	
	uint32_t epoch_reference_time;
	message_t beacon;
	Msg to_send;
	bool first_run;

	event void Boot.booted() 
	{
		// turn on the radio
		call AMControl.start();
		first_run = TRUE;

		
	}
	
	
	
	event void AMControl.startDone(error_t err) 
	{
			
		if (IS_MASTER && first_run) 
		{
			call TimerInitialize.startOneShot(3*SECOND);	//call TDMA layer after 3 seconds				
		}
		
	}

	
	event void TimerInitialize.fired() 
	{
		printf("[APP] TDMA layer started \n");
		first_run = FALSE;
		call AppInterface.startTdma();			
			
	}
	

	event void AMControl.stopDone(error_t err){	}
	
	
	// Called from TDMA layer in each epoch to fetch a new packet, if any
	event Msg AppInterface.receivePacket()
	{
				
		to_send.data = (call Random.rand16())%50;
		
		if( to_send.data%2 )					//decides wether or not 														
			 printf("[APP] A new message is available \n");	
			 
															//to send a packet if a random number is even  
		
		else
		{
			to_send.data = -1; //no packets to send
			printf("[APP] There is NO packet to send! \n");
		}
			
		
		return to_send;
	
	}
}

