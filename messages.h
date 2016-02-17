#ifndef MESSAGES_H
#define MESSAGES_H
#define MAX_SLOTS 17

enum {
	AM_BEACONMSG = 130,
	AM_DATA = 150,
	AM_JOIN_REQ = 151,
	AM_JOIN_REP = 154,
	
	//AM_JOIN_REQ = 150,
	//AM_JOIN_REP = 166,
};
//beacon
typedef nx_struct BeaconMsg {
	nx_uint16_t current_slot;
	
} BeaconMsg;

//data message
typedef nx_struct Msg {
	nx_uint16_t data;
	nx_bool is_data;
} Msg;

//Confirmation message
typedef nx_struct ConfMsg {

	nx_uint16_t slot;
	nx_bool is_data;
	
} ConfMsg;


#endif
