#include <AM.h>
#include "messages.h"

interface App_interface {

	command void start_tdma();
	event Msg receive_packet();
  
}
