#include <AM.h>
#include "messages.h"

interface AppInterface {

	command void startTdma();
	event Msg receivePacket();
  
}
