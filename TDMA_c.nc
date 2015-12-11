#include <Timer.h>
#include "messages.h"
configuration TDMA_c {

provides interface App_interface;


}
implementation {
	components TDMA_p as AppP;
	components SerialPrintfC, SerialStartC;
	components PacketLinkC;
	//components new Timer32C() as TimerBeaconTx;
	components new Timer32C() as TimerFirstSlot;
	components new Timer32C() as TimerCheckForBeacon ;
	components new Timer32C() as TimerOff;
	components new Timer32C() as TimerEpoch;
	components new Timer32C() as TimerCheckJoined;
	components new Timer32C() as TimerOn;
	components new Timer32C() as TimerSendBeacon;
	components new Timer32C() as TimerSlots;
	components new AMSenderC( AM_DATA) as SenderC;
	
	////////
	/*
	components new AMSenderC( AM_JOIN_REQ) as SendJoinC;
	components new AMSenderC( AM_JOIN_REP) as SendJoinReplyC;
	components new AMReceiverC( AM_JOIN_REP) as ReceiveJoinReplyC;
	components new AMReceiverC(AM_JOIN_REQ) as ReceiverJoinC;
	
	AppP.ReceiveJoin -> ReceiveJoinC;
	AppP.SendJoin -> SendJoinC;
	AppP.SendJoinReply -> SendJoinReplyC;
	*/
	///////
	
	
	components new AMReceiverC(AM_DATA) as ReceiverC;

	components RandomC;
	components RandomMlcgC;
	components CC2420TimeSyncMessageC as TSAM;
	
	components ActiveMessageC;

	AppP.TSPacket -> TSAM.TimeSyncPacket32khz;
	AppP.SendBeacon -> TSAM.TimeSyncAMSend32khz[AM_BEACONMSG]; // wire to the beacon AM type
	AppP.ReceiveBeacon -> TSAM.Receive[AM_BEACONMSG];       
	//AppP.RadioBackoff -> RadioBackoff;
	
	
	AppP.AMSend -> SenderC;
	AppP.Receive -> ReceiverC;
	App_interface = AppP.App_interface;
	AppP.PacketLink -> PacketLinkC;
	//AppP.TimerBeaconTx -> TimerBeaconTx;
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