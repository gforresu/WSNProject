#include <Timer.h>
#include "messages.h"

configuration AppC {


}
implementation {

components AppP, MainC, TDMA_c as tdma;
components new Timer32C() as TimerInitialize;
components new Timer32C() as TimerEpoch;

components CC2420TimeSyncMessageC as TSAM;
components PacketLinkC;
components RandomC;


components CC2420ActiveMessageC;
components ActiveMessageC;

//AppP.Receive -> ReceiverC;
AppP.AMControl -> ActiveMessageC;
AppP.App_interface -> tdma ;
AppP.Boot -> MainC;
AppP.Random -> RandomC;
AppP.TSPacket -> TSAM.TimeSyncPacket32khz;
//AppP.SendBeacon -> TSAM.TimeSyncAMSend32khz[AM_BEACONMSG];
AppP.TimerInitialize -> TimerInitialize;
AppP.PacketLink -> PacketLinkC;


}