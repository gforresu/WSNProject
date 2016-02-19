#include <Timer.h>
#include "messages.h"
#include <printf.h>

module TDMA_p {

	provides interface AppInterface;
	  

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
		//interface Receive;
		interface AMPacket;		
		//interface AMSend;
		interface AMSend as SendJoinRequest;
		interface AMSend as SendAssignedSlot;
		interface AMSend as SendData;
		
		interface Receive as ReceiveSlot;
		interface Receive as ReceiveJoinRequest;
		interface Receive as ReceiveData;
		
		interface Random;
		
			
		
	}
}
implementation {

#define SECOND 32768L

#define IS_MASTER (TOS_NODE_ID==1)
#define IS_SLAVE (TOS_NODE_ID != 1)
#define SLOT_DURATION (SECOND/50)
#define SAFE_PADDING (SECOND/600)

#define ON_DURATION (SECOND/16)

#define MAX_SLOTS 17
#define MAX_RETRIES 5
#define EPOCH_DURATION (MAX_SLOTS*SLOT_DURATION)

void startEpochs();
int checkAssignedSlot(int);
void resynchronize();
void sendJoinRequest();


uint32_t epoch_reference_time;
uint32_t current_time;
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
bool joined;
bool resync;
bool beacon_received;
int seed;
uint32_t random_delay;
Msg app_level_message;
bool incoming_message;
bool initialize;



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

		resync = FALSE;	
				
		call AMControl.start();

		
		if(IS_MASTER)	
			epoch_reference_time += EPOCH_DURATION;
			
			
		beacon_received = FALSE;
		
		call AppInterface.startTdma() ;
		
	
	}
	
	
	event void TimerSlots.fired()
	{
				
		call PacketLink.setRetries(&data, 1);
		
		call SendData.send( 1 , &data, sizeof(Msg));

	}
	
	
	
		event void TimerCheckJoined.fired()
	{
	
		if(IS_MASTER)
			startEpochs();
			
		
		else //slaves turn off their radio if master didn't reply
		{
			if( ! joined)
			{
				printf("TimerCheckJoined- Master didn't reply during the first slot. Switching off the radio\n");
				call AMControl.stop();
			}
				
		}
			
			
	}
	
	
	event void TimerCheckForBeacon.fired()
	{
		
		printf("TimerCheckForBeacon \n");
		
		//if(!joined && IS_SLAVE)
		
			if(retries > 0 )
			{
	
				
				if(! beacon_received )
				{
					
					retries -- ;
					epoch_reference_time += EPOCH_DURATION ;
										
					
					if(!joined)
						sendJoinRequest();
						
					else //if it's already joined continues with his normal schedule
						startEpochs();
				
					
					
				}
				
					
			}
				
			
			else
			{
				printf("[TDMA] No beacon received in 5 epochs ... resync \n");
				resynchronize();
			
			}
		
					
				
			
					
	}
	
	command void AppInterface.startTdma()
	{
		////Called only the first time
		if( ! initialize )
		{
			
			last_slot_assigned = 1; //slot 0 and 1 are reserved
			//current_slot = 0; 
			my_slot = -1;

			initialize = TRUE;
		
		}
		
		
		//seed = (seed + TOS_NODE_ID)%100;
		
		//call Seed.init(seed);
		
		if(IS_MASTER)
		{
		
			if( epoch_reference_time == 0)
				epoch_reference_time = call TimerSendBeacon.getNow();
			
			call TimerEpoch.startPeriodicAt(epoch_reference_time, EPOCH_DURATION);

			//message_to_send = call AMSend.getPayload(&beacon, sizeof(BeaconMsg));
			message_to_send = call SendBeacon.getPayload(&beacon, sizeof(BeaconMsg));
			
			call TimerSendBeacon.startOneShotAt( epoch_reference_time , SLOT_DURATION/5 + (call Random.rand16()%(SLOT_DURATION / 2)));
		
		}
		
	}
	
	
	event message_t* ReceiveJoinRequest.receive(message_t* msg, void* payload, uint8_t len)
	{
		join_message = (Msg*) payload;
		from = call AMPacket.source(msg);
		
		current_time = call TimerSendBeacon.getNow();
		
		atomic
		{	
			if(current_time < epoch_reference_time + 2*SLOT_DURATION) //master replies only during the slot 1
			{
			
				call PacketLink.setRetries(&conf, 0 );
			
				if( checkAssignedSlot(from) == -1 )
				{
			
					//printf("Received join from %d \n", from);
			
					confirmation_message = call SendAssignedSlot.getPayload(&conf, sizeof(ConfMsg));
		
					confirmation_message -> slot = last_slot_assigned +1;			
																
					if ( call SendAssignedSlot.send( from , &conf, sizeof(ConfMsg)) == SUCCESS)
					{
						last_slot_assigned += 1;	
						slots[last_slot_assigned] = from;
							
			
						printf("[TDMA][MASTER]Join received from %d - Slot %d assigned \n", from , last_slot_assigned);	
					}
					
					else
						printf("[TDMA][MASTER] Reply to slave not succeded \n ");
			
				}
			
			
				else
				{
					confirmation_message = call SendAssignedSlot.getPayload(&conf, sizeof(ConfMsg));
		
					confirmation_message -> slot = checkAssignedSlot(from);			
																			
					if (call SendAssignedSlot.send( from , &conf, sizeof(ConfMsg)) != SUCCESS)
						printf("[TDMA][MASTER] Reply to slave not succeded \n ");
						
			
				}
				
			}
						
					
					
	

		}
		
		return msg;
		
		
	}
	
	
	event message_t* ReceiveSlot.receive(message_t* msg, void* payload, uint8_t len)
	{
		confirmation_message = (ConfMsg*) payload;
													
		my_slot = confirmation_message->slot ;
		
		printf("Received slot number %d \n", my_slot);
				 
		resync = FALSE;
		joined=TRUE;
		
		startEpochs();	
		
		retries = MAX_RETRIES;
		
		
		return msg;
				
			
			
	}
	
	
	event message_t* ReceiveData.receive(message_t* msg, void* payload, uint8_t len)
	{
		printf("[MASTER] Received a data message from slave %d \n", call AMPacket.source(msg));
		return msg;
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


			epoch_reference_time = call TSPacket.eventTime(msg);
			
			
			call TimerCheckForBeacon.startPeriodicAt(epoch_reference_time + SLOT_DURATION, EPOCH_DURATION );
			
						
			call TimerEpoch.startPeriodicAt(epoch_reference_time, EPOCH_DURATION);
			
			if( ! joined )	//not joined yet
				sendJoinRequest();				
				

				
			else //already joined
				startEpochs();
					
		}	
		
		else
			printf("Node %d Beacon is not a valid packet \n", TOS_NODE_ID);			
								
				
		
		return msg;		
		
	}
	
	
	void sendJoinRequest()
	{
	
	
		join_message = call SendJoinRequest.getPayload(&join, sizeof(Msg));
				//slaves send join request at slot 1 
		random_delay = SLOT_DURATION + call Random.rand16()%(SLOT_DURATION*5/8 )  + SLOT_DURATION/30 - SAFE_PADDING;
			
			
		printf("Random delay %lu \n", random_delay);
	
	
		
		call TimerFirstSlot.startOneShotAt(epoch_reference_time, random_delay); //send the request at random time 
		
		call TimerCheckJoined.startOneShotAt(epoch_reference_time, 2*SLOT_DURATION); //checks for master reply
	
	}
	
	
	
	//Slaves send join requests
	event void TimerFirstSlot.fired()
	{

		
		if(IS_SLAVE)
		{
			
			printf("[TDMA] Sending join request - sendind to MASTER \n");
			call PacketLink.setRetries(&join, 0);
			call SendJoinRequest.send( 1 , &join, sizeof(Msg));	
		}
		
			
	}
	

	// initialise and schedules the slots
	void startEpochs() 
	{
		
		if(IS_SLAVE && ! resync) //slaves start their epochs
		{
		
			call AMControl.stop();
			
			
			start_slot = my_slot * SLOT_DURATION ;
			end_slot = start_slot + SLOT_DURATION ;

						
			call TimerOn.startOneShotAt(epoch_reference_time, start_slot );
			call TimerOff.startOneShotAt(epoch_reference_time, end_slot );
		
		}
		
		
		else if(IS_MASTER) //master switch off the radio			
			call TimerOff.startOneShotAt(epoch_reference_time, SLOT_DURATION*(last_slot_assigned +1) );	
		
		
	}

	
	//sends stuff...
	event void TimerOn.fired() {
		
		app_level_message.data = -1;
		
		app_level_message = signal AppInterface.receivePacket();
		
			
		if(IS_SLAVE && (app_level_message.data != (-1) ))
		{
			
			call AMControl.start();
				
			data_message = call SendData.getPayload(&data, sizeof(Msg));
			
		
			data_message-> data = app_level_message.data;
				
			call TimerSlots.startOneShotAt(epoch_reference_time, start_slot + SLOT_DURATION/5 + (call Random.rand16()%(SLOT_DURATION / 2))  );
		
		}
		
		else
		{
			call AMControl.stop();
			printf("[TDMA] No data from App level: radio off\n");	
		}
			
		
		
		
		
	}
	event void TimerOff.fired() {
		
		if(IS_MASTER)
			printf("[TDMA][MASTER] %d slaves requested to join \n", last_slot_assigned );
		
		
		call AMControl.stop();
	
	}
	
	
	event void SendJoinRequest.sendDone(message_t* msg, error_t err)
	{
	
	}
	
	
	event void SendData.sendDone(message_t* msg, error_t err)
	{
		
	}
	
	event void SendAssignedSlot.sendDone(message_t* msg, error_t err)
	{
	
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
	

	
	int checkAssignedSlot(int slave)
	{
		int i;
		
		for(i=0; i<= last_slot_assigned; i++)
			if( slots[i] == slave )
				return i ;
		
		return -1 ;
			
	
	}
	
	


}