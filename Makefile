#COMPONENT = AppC
COMPONENT = AppC

#CFLAGS += -DCC2420_DEF_RFPOWER=31
#CFLAGS += -DCC2420_DEF_CHANNEL=18
#CFLAGS += -DPACKET_LINK
#CFLAGS += -DLOW_POWER_LISTENING
#CFLAGS += -DCC2420_HW_ACKNOWLEDGEMENTS 
#CFLAGS += -DCC2420_HW_ADDRESS_RECOGNITION
#CFLAGS += -DTOSH_DATA_LENGTH=30

#include $(TINYOS_ROOT_DIR)/Makefile.include

TINYOS_ROOT_DIR?=/user/tinyos
CFLAGS += -I$(TINYOS_ROOT_DIR)/tos/lib/printf
CFLAGS += -DNEW_PRINTF_SEMANTICS

# max payload size, may grow up to 90 (circa)
CFLAGS += -DTOSH_DATA_LENGTH=28
# radio frequency channel from 11 to 26
CFLAGS += -DCC2420_DEF_CHANNEL=26

# include the low power listening component
#CFLAGS += -DLOW_POWER_LISTENING

# wake-up interval
#CFLAGS += -DLPL_DEF_REMOTE_WAKEUP=256
#CFLAGS += -DLPL_DEF_REMOTE_WAKEUP=0 # 0 means no LPL

# include the packet link (acknowledgements) component
CFLAGS += -DPACKET_LINK

include $(TINYOS_ROOT_DIR)/Makefile.include