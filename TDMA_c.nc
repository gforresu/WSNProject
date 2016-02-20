#include <Timer.h>
#include "messages.h"
configuration TDMA_c {

provides interface AppInterface;


}
implementation 
{
	components TDMA_p as AppP;
	components SerialPrintfC, SerialStartC;
	components PacketLinkC;
	
	//Timers
	components new Timer32C() as TimerFirstSlot;
	components new Timer32C() as TimerCheckForBeacon ;
	components new Timer32C() as TimerOff;
	components new Timer32C() as TimerEpoch;
	components new Timer32C() as TimerCheckJoined;
	components new Timer32C() as TimerOn;
	components new Timer32C() as TimerSendBeacon;
	components new Timer32C() as TimerSlots;
	
	components new AMSenderC( AM_DATA) as SenderDataC;
	components new AMSenderC( AM_JOIN_REQ) as SenderJoinReqC; //Sends join request
	components new AMSenderC( AM_JOIN_REP) as SenderJoinRepC; //Used by the master to send its reply
	
	components new AMReceiverC(AM_DATA) as ReceiverDataC;
	components new AMReceiverC(AM_JOIN_REQ) as ReceiverJoinReqC;
	components new AMReceiverC(AM_JOIN_REP) as ReceiverJoinRepC;
	


	components RandomC;
	components RandomMlcgC;
	components CC2420TimeSyncMessageC as TSAM;
	
	components ActiveMessageC;

	AppP.TSPacket -> TSAM.TimeSyncPacket32khz;
	AppP.SendBeacon -> TSAM.TimeSyncAMSend32khz[AM_BEACONMSG]; // wire to the beacon AM type
	AppP.ReceiveBeacon -> TSAM.Receive[AM_BEACONMSG];       
	
	
	AppP.SendJoinRequest -> SenderJoinReqC;
	AppP.SendAssignedSlot -> SenderJoinRepC;
	AppP.SendData -> SenderDataC;
	
	
	AppP.ReceiveSlot -> ReceiverJoinRepC;
	AppP.ReceiveData -> ReceiverDataC;
	AppP.ReceiveJoinRequest -> ReceiverJoinReqC;
	
	AppInterface = AppP.AppInterface;
	AppP.PacketLink -> PacketLinkC;
	AppP.TimerOff -> TimerOff;
	AppP.TimerOn -> TimerOn;
	AppP.TimerSlots -> TimerSlots ;
	AppP.TimerCheckForBeacon -> TimerCheckForBeacon;
	AppP.TimerFirstSlot -> TimerFirstSlot ;
	AppP.TimerEpoch -> TimerEpoch;
	AppP.TimerSendBeacon -> TimerSendBeacon;
	AppP.TimerCheckJoined -> TimerCheckJoined;
	AppP.AMControl -> ActiveMessageC;
	AppP.AMPacket -> ActiveMessageC;
	AppP.Random -> RandomC;
	AppP.Seed -> RandomMlcgC.SeedInit;

	
}