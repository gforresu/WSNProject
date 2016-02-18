#include <Timer.h>
#include "messages.h"

configuration AppC {


}
implementation {

components AppP, MainC, TDMA_c as tdma;
components new Timer32C() as TimerInitialize;
components new Timer32C() as TimerEpoch;
components SerialPrintfC, SerialStartC;

components CC2420TimeSyncMessageC as TSAM;
components PacketLinkC;
components RandomC;


components CC2420ActiveMessageC;
components ActiveMessageC;

AppP.AMControl -> ActiveMessageC;
AppP.AppInterface -> tdma ;
AppP.Boot -> MainC;
AppP.Random -> RandomC;
AppP.TSPacket -> TSAM.TimeSyncPacket32khz;
AppP.TimerInitialize -> TimerInitialize;
AppP.PacketLink -> PacketLinkC;


}