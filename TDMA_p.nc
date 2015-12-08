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
#define SLOT_DURATION (SECOND/8)
#define SLOT_DURATION13 1365L
#define SLOT_DURATION53 61440L
#define SLOT_DURATION23 2730L
#define ON_DURATION (SECOND/16)

#define MAX_SLOTS 30
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
int current_slot;
bool joined;
bool resync;
bool beacon_received;
int seed;
uint32_t random_delay;
Msg app_level_message;
bool incoming_message;



	event void AMControl.startDone(error_t err)
	{
	

	}

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
		epoch_reference_time = 0;
		joined=FALSE;
		resync = FALSE;	
		
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
		
		call PacketLink.setRetries(&data, 1);
			
		call AMSend.send( 1 , &data, sizeof(Msg));

	}
	
	
		event void TimerCheckJoined.fired()
	{
		start_epochs();
	}
	
	
	event void TimerCheckForBeacon.fired()
	{
		if(!joined && IS_SLAVE)
		{
			if(retries > 0 )
			{
				call AMControl.stop();
					
				
				if(! beacon_received)
				{
					retries -- ;
					epoch_reference_time += EPOCH_DURATION ;
					printf("OUCH!! NO BEACON received after 2 slots... switching off the radio\n");
				}
				
				else
					printf("OUCH!! NO CONFIRMATION received after 2 slots... switching off the radio\n");
		
					
				
					
			}
				
			
			else
			{
				printf("OUCH!! No beacon received after 5 ATTEMPTS ... resync \n");
				resynchronize();
			
			}
	
		}
				
			
	
	}
	
	command void App_interface.start_tdma()
	{
		
		last_slot_assigned = 2; //slot 0 and 1 are reserved
		current_slot = 0; 
		my_slot = -1;
		seed = (seed + TOS_NODE_ID)%100;
		
		call Seed.init(seed);
	//	printf("New epoch started \n");
		
		if(IS_MASTER)
		{
		
			if( epoch_reference_time == 0)
				epoch_reference_time = call TimerSendBeacon.getNow();
			
			call TimerEpoch.startOneShotAt(epoch_reference_time, EPOCH_DURATION);

			//call TimerSlots.startPeriodicAt(epoch_reference_time, SLOT_DURATION);
			message_to_send = call AMSend.getPayload(&beacon, sizeof(BeaconMsg));
			
			//call SendBeacon.send(AM_BROADCAST_ADDR, &beacon, sizeof(BeaconMsg), epoch_reference_time);	
			call TimerSendBeacon.startOneShotAt( epoch_reference_time , SLOT_DURATION/4 + (call Random.rand32()%(SLOT_DURATION/2)) ) ;
		}
		
	}
	
	
	event message_t* ReceiveBeacon.receive(message_t* msg, void* payload, uint8_t len)
	{
		// we have to check whether the packet is valid before retrieving the reference time
		
		if (call TSPacket.isValid(msg) && len == sizeof(BeaconMsg)) 
		{
			beacon_received = TRUE;
			
			from = call AMPacket.source(msg);
			
			current_slot = 0;//((BeaconMsg*) msg)->current_slot;
		
			printf(" [ %d ]- Beacon Received from %d  \n", TOS_NODE_ID, from);
				// get the epoch start time (converted to our local time reference frame)
			
			//if(!joined)
			epoch_reference_time = call TSPacket.eventTime(msg);
			// turn off the radio
			
							
			join_message = call AMSend.getPayload(&join, sizeof(Msg));

			//slaves send join request at slot 1 
			random_delay = (call Random.rand32())%(SLOT_DURATION - SLOT_DURATION/10) ;
			
			call TimerFirstSlot.startOneShotAt(epoch_reference_time, SLOT_DURATION + random_delay);
			
					
			call TimerEpoch.startOneShotAt(epoch_reference_time, EPOCH_DURATION);
			
			call TimerCheckForBeacon.startOneShotAt(epoch_reference_time, 2*SLOT_DURATION);	
		
			
			
		}
			
		
		return msg;		
		
	}
	
	
	event message_t* Receive.receive(message_t* msg, void* payload, uint8_t length)
	{
		
		join_message = (Msg*) payload;
		from = call AMPacket.source(msg);

		
		if(IS_MASTER && !join_message->is_data) //is a join message
		{	
			//Receiving a join request
			{
														
				printf("Join received from %d - Slot %d assigned \n", from , last_slot_assigned);
																		
				
				
				confirmation_message = call AMSend.getPayload(&conf, sizeof(ConfMsg));
				
				confirmation_message -> slot = last_slot_assigned ;			
				
				
				call AMSend.send( from , &conf, sizeof(ConfMsg));	
					

				 
			}
					
			
		}
		
				
		else if(IS_SLAVE)
		{
			confirmation_message = (ConfMsg*) payload;
					
			//if(confirmation_message->slot[TOS_NODE_ID + 2] != -1)
			{
			 //	printf("OK! Received from MASTER the slot n. %d \n", confirmation_message->slot);//join_message->slot);
				
				
				my_slot = confirmation_message->slot ;
						 
				resync = FALSE;
				
				start_epochs();	
				
				retries = MAX_RETRIES;
				
				joined=TRUE;
				
					
			}
			
			//else if(from != 1)//message delivered to wrong node
				//printf("Error - Received a packet from %d \n", call AMPacket.source(msg));
		
		}
					
		
		return msg;
	
	}
	
	event void TimerFirstSlot.fired()
	{
		
		if(IS_SLAVE)
		{
			printf("Sending join request - sendind to %d \n", from);

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
			end_slot = my_slot * SLOT_DURATION + SLOT_DURATION ;

						
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
		
		if(IS_SLAVE && app_level_message.data >= 0)
		{
			call AMControl.start();
				
			data_message = call AMSend.getPayload(&data, sizeof(Msg));
			
			data_message -> is_data = TRUE;
			
			data_message-> data = app_level_message.data;
				
			call TimerSlots.startOneShotAt(epoch_reference_time, start_slot + (call Random.rand32()%(SLOT_DURATION/2)) + SLOT_DURATION/5);
		
		}
		
		else
			printf("No data from App level: radio off\n");
		
		
		
		
	}
	event void TimerOff.fired() {
		
		if(IS_MASTER)
			printf("[MASTER] %d slaves joined \n", last_slot_assigned - 2);
		
		
		call AMControl.stop();
	
	}
	
	
	
	
	event void SendBeacon.sendDone(message_t* msg, error_t err)
	{
		call TimerCheckJoined.startOneShotAt(epoch_reference_time, 2*SLOT_DURATION ) ; //waits 2 slots
	
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
				slots[last_slot_assigned] = from;
				
				last_slot_assigned = (last_slot_assigned+1) % MAX_SLOTS;				
			}

		}
		
		
		else
		{
	
			if ( call PacketLink.wasDelivered(&data) )
			{
				printf("[PacketLink.wasDelivered] Data has been successfully received from master \n");
				incoming_message = FALSE;
			
			}	
				

		}
	
			 
		 
	
	}
	
	
	




}