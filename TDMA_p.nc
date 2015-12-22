#include <Timer.h>
#include "messages.h"
#include <printf.h>

module TDMA_p {

	provides interface App_interface;
	  

	uses { 
		interface ParameterInit<uint16_t> as Seed;
		//interface Timer<T32khz> as TimerBeaconTx;
		interface Timer<T32khz> as TimerOn;
		interface Timer<T32khz> as TimerFirstSlot;
		interface Timer<T32khz> as TimerCheckForBeacon;
		interface Timer<T32khz> as TimerSlots;
		interface Timer<T32khz> as TimerSendBeacon;
		interface Timer<T32khz> as TimerOff;
		interface Timer<T32khz> as TimerCheckJoined;
		interface Timer<T32khz> as TimerEpoch;
    	interface TimeSyncAMSend<T32khz, uint32_t> as SendBeacon;
        interface TimeSyncPacket<T32khz, uint32_t> as TSPacket;
    	interface Receive as ReceiveBeacon;
		
	/*	
		interface Receive as ReceiveJoin;
		interface AMSend as SendJoin;
		//interface AMSend as SendData;
		interface AMSend as SendJoinReply;
	*/	
		interface SplitControl as AMControl;
		interface PacketLink;
		interface Receive;
		interface AMPacket;		
		interface AMSend;
		interface Random;

		
		
	}
}
implementation {

#define SECOND 32768L
#define EPOCH_DURATION (SECOND*2)
#define IS_MASTER (TOS_NODE_ID==1)
#define IS_SLAVE (TOS_NODE_ID != 1)
#define SLOT_DURATION (SECOND/50)

#define ON_DURATION (SECOND/16)

#define MAX_SLOTS 17
#define MAX_RETRIES 5
#define EPOCHS 16

void start_epochs();
void resynchronize();


uint32_t epoch_reference_time;
uint32_t start_slot;
uint32_t end_slot;
BeaconMsg* message_to_send;
int my_slot;

Msg* join_message;
Msg* data_message;
ConfMsg* confirmation_message;

am_addr_t from;
	message_t beacon;
	message_t join;
	message_t data;
	message_t conf;
	
int retries = MAX_RETRIES ;


int last_slot_assigned;

uint16_t slots[MAX_SLOTS];
//int current_slot;
bool joined;
bool resync;
bool beacon_received;
int seed;
uint32_t random_delay;
Msg app_level_message;
bool incoming_message;
bool initialize;
bool join_booked;
bool is_busy;
int misses;



	event void AMControl.startDone(error_t err){}

	/*
		Choose a rundom time interval in slot=0 to send the beacon
	*/
	event void TimerSendBeacon.fired()
	{	
		call SendBeacon.send(AM_BROADCAST_ADDR, &beacon, sizeof(BeaconMsg), epoch_reference_time);
	}
	
	/*
		
	*/
	event void TimerEpoch.fired()
	{
		//epoch_reference_time = 0;
		//joined=FALSE;
		resync = FALSE;	
		//join_booked=FALSE;
				
		call AMControl.start();
		
		
		
		if(IS_MASTER)
		{
			epoch_reference_time = call TimerSendBeacon.getNow();		
			//epoch_reference_time += EPOCH_DURATION;
		}
			
		beacon_received = FALSE;
		
		
		
		call App_interface.start_tdma() ;
		
		
	}
	
	
	event void TimerSlots.fired()
	{
				
		call PacketLink.setRetries(&data, 1);
			
		call AMSend.send( 1 , &data, sizeof(Msg));

	}
	
	
		event void TimerCheckJoined.fired()
	{
		start_epochs();
	}
	
	
	event void TimerCheckForBeacon.fired()
	{
		
		printf("TimerCheckForBeacon \n");
		
		//if(!joined && IS_SLAVE)
		{
			if(retries > 0 )
			{
				//call AMControl.stop();
				
				if(! joined )
				{
					call AMControl.stop();
					misses = (misses + 1) % 20 ;
				}
					
				
				if(! beacon_received )
				{
					call AMControl.stop();
					retries -- ;
					epoch_reference_time = epoch_reference_time + EPOCH_DURATION ;
					call TimerCheckForBeacon.startOneShotAt(epoch_reference_time, 2* SLOT_DURATION + SLOT_DURATION/10);
					printf("[TDMA] OUCH!! NO BEACON received in this epoch\n");
				}
				
				/*
				else if( beacon_received && ! joined)
				{
					call AMControl.stop();
				}
				*/
				/*
				else if( ! beacon_received && ! joined)
				{
					epoch_reference_time = epoch_reference_time + EPOCH_DURATION ;
					call AMControl.stop();
				}
					*/
				
				//else
					//printf("[TDMA] OUCH!! NO CONFIRMATION received after 2 slots... switching off the radio\n");
		
					
				
					
			}
				
			
			else
			{
				printf("[TDMA] OUCH!! No beacon received after 5 ATTEMPTS ... resync \n");
				resynchronize();
			
			}
	
		}
				
			
					
	}
	
	command void App_interface.start_tdma()
	{
		////Called only the first time
		if( ! initialize )
		{
			
			last_slot_assigned = 2; //slot 0 and 1 are reserved
			//current_slot = 0; 
			my_slot = -1;
			
			misses = 0;
			initialize = TRUE;
		
		}
		
		
		seed = (seed + TOS_NODE_ID)%100;
		
		call Seed.init(seed);
		
		if(IS_MASTER)
		{
		
			if( epoch_reference_time == 0)
				epoch_reference_time = call TimerSendBeacon.getNow();
			
			call TimerEpoch.startOneShotAt(epoch_reference_time, EPOCH_DURATION);

			message_to_send = call AMSend.getPayload(&beacon, sizeof(BeaconMsg));
			
			call TimerSendBeacon.startOneShotAt( epoch_reference_time , SLOT_DURATION/5 + (call Random.rand32()%(SLOT_DURATION / 2)));
		
		}
		
	}
	
	
	event message_t* ReceiveBeacon.receive(message_t* msg, void* payload, uint8_t len)
	{
		// we have to check whether the packet is valid before retrieving the reference time
		
		if (call TSPacket.isValid(msg) && len == sizeof(BeaconMsg)) 
		{
			beacon_received = TRUE;
			
			retries = MAX_RETRIES ;
			
			from = call AMPacket.source(msg);
		
			printf("[TDMA] [ %d ]- Beacon Received from %d  \n", TOS_NODE_ID, from);
			
			//call AMControl.stop();

			epoch_reference_time = call TSPacket.eventTime(msg);
			
			if( ! joined )	//not joined yet
			{
				
				join_message = call AMSend.getPayload(&join, sizeof(Msg));

				//slaves send join request at slot 1 
				
				
				/*
				if(! join_booked) 
				{
					join_booked= TRUE;
					random_delay = SLOT_DURATION + call Random.rand16()%(SLOT_DURATION /2) + EPOCH_DURATION*(call Random.rand16() % 5)   ;
				
				}
				
				*/
				//else
				{
					//if(misses < 5)
					random_delay = SLOT_DURATION + call Random.rand16()%(SLOT_DURATION - SLOT_DURATION/10)+ EPOCH_DURATION*(call Random.rand16() % 2) ;
				
				//	else
						//random_delay = SLOT_DURATION + call Random.rand16()%(SLOT_DURATION / 2 ) ;
				}	
				
				printf("Random delay %lu \n", random_delay); //+ EPOCH_DURATION*(call Random.rand32());//- SLOT_DURATION/10) ;
			
			
				call TimerFirstSlot.startOneShotAt(epoch_reference_time, random_delay);
				
				//after receiving the first beacon checks wether the next ones have been received				
				call TimerCheckForBeacon.startOneShotAt(epoch_reference_time, 2* SLOT_DURATION + SLOT_DURATION/10);
								
				
			}
			
			else //already joined
			{
				start_epochs();
					
			}
			
						
			
			
					
			call TimerEpoch.startOneShotAt(epoch_reference_time, EPOCH_DURATION);
			
			
		
			
			
		}
			
		
		return msg;		
		
	}
	
	
	event message_t* Receive.receive(message_t* msg, void* payload, uint8_t length)
	{
		
		
			join_message = (Msg*) payload;
			from = call AMPacket.source(msg);
					
			if(IS_MASTER && !join_message->is_data && last_slot_assigned < MAX_SLOTS) //is a join message
			{	
				atomic
				{	
					printf("Received join from %d \n", from);
					
					confirmation_message = call AMSend.getPayload(&conf, sizeof(ConfMsg));
				
					confirmation_message -> slot = last_slot_assigned ;			
												
					call PacketLink.setRetries(&conf, 1 );
										
					call AMSend.send( from , &conf, sizeof(ConfMsg));
	

				}
		} 
		
				
		else if(IS_SLAVE)
		{
			confirmation_message = (ConfMsg*) payload;
					
			{
									
				my_slot = confirmation_message->slot ;
				
				printf("Received slot number %d \n", my_slot);
						 
				resync = FALSE;
				joined=TRUE;
				
				start_epochs();	
				
				retries = MAX_RETRIES;
				
				
				
					
			}
		}
					
		
		return msg;
	
	}
	
	//Slaves send join requests
	event void TimerFirstSlot.fired()
	{

		
		if(IS_SLAVE)
		{
			printf("[TDMA] Sending join request - sendind to %d \n", from);
			call AMSend.send( 1 , &join, sizeof(Msg));	
		}
		
			
	}
	

	// initialise and schedules the slots
	void start_epochs() 
	{
		
		if(IS_SLAVE && ! resync) //slaves start their epochs
		{
		
			call AMControl.stop();
			
			
			start_slot = my_slot * SLOT_DURATION ;
			end_slot = start_slot + SLOT_DURATION ;

						
			call TimerOn.startOneShotAt(epoch_reference_time, start_slot );
			call TimerOff.startOneShotAt(epoch_reference_time, end_slot );
		
		}
		
		
		else if(IS_MASTER) //master check the number of joined members 
		{		
			
			call TimerOff.startOneShotAt(epoch_reference_time, SLOT_DURATION*last_slot_assigned );	
		}
		
		
	}

	
	//sends stuff...
	event void TimerOn.fired() {
		
		app_level_message.data = -1;
		
		app_level_message = signal App_interface.receive_packet();
		
			
		if(IS_SLAVE && (app_level_message.data != (-1) ))
		{
			
			call AMControl.start();
				
			data_message = call AMSend.getPayload(&data, sizeof(Msg));
			
			call PacketLink.setRetries(&data, 0);
			
			data_message -> is_data = TRUE;
			
			data_message-> data = app_level_message.data;
				
			call TimerSlots.startOneShotAt(epoch_reference_time, start_slot + (call Random.rand16()%(SLOT_DURATION/2) + SLOT_DURATION/10  ));
		
		}
		
		else
			printf("[TDMA] No data from App level: radio off\n");
		
		
		
		
	}
	event void TimerOff.fired() {
		
		if(IS_MASTER)
			printf("[TDMA][MASTER] %d slaves joined \n", last_slot_assigned );
		
		
		call AMControl.stop();
	
	}
	
	
	
	
	event void SendBeacon.sendDone(message_t* msg, error_t err)
	{
		call TimerCheckJoined.startOneShotAt(epoch_reference_time, 2*SLOT_DURATION + SLOT_DURATION/10) ; //waits 2 slots
		
	}
	

	
	event void AMControl.stopDone(error_t err) {}
	
	
	void resynchronize()
	{
		resync = TRUE;
		
		if(! beacon_received)
			epoch_reference_time += EPOCH_DURATION;
			
		call AMControl.start();
	
	}
	
	
	event void AMSend.sendDone(message_t* msg, error_t error)
	{
		
		
		if(IS_MASTER) 
		{	
			atomic
			{	
				if( call PacketLink.wasDelivered(&conf)) 
				{									
					slots[last_slot_assigned] = from;
					
					printf("[TDMA][MASTER]Join received from %d - Slot %d assigned \n", from , last_slot_assigned);		
					
					last_slot_assigned = (last_slot_assigned+1) % (MAX_SLOTS);			
				}
				
				else
					printf("COLLISION! Slot assignment failed \n");
				
						
			}

		}
		
		
		else
		{
	
			if ( call PacketLink.wasDelivered(&data) )
				printf("[TDMA][PacketLink.wasDelivered] Data has been successfully received from master \n");

		}
	
			 
		 
	
	}
	


}