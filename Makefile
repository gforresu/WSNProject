#COMPONENT = AppC
COMPONENT = AppC

COMPONENT=AppC
TINYOS_ROOT_DIR?=/home/user/tinyos

# max payload size, may grow up to 90 (circa)
CFLAGS += -DTOSH_DATA_LENGTH=28
# radio frequency channel from 11 to 26
CFLAGS += -DCC2420_DEF_CHANNEL=26
# transmission power from 1 to 31
CFLAGS += -DCC2420_DEF_RFPOWER=31


# include the packet link (acknowledgements) component
CFLAGS += -DPACKET_LINK
CFLAGS += -DCC2420_HW_ACKNOWLEDGEMENTS 
CFLAGS += -DCC2420_HW_ADDRESS_RECOGNITION

CFLAGS += -I$(TINYOS_ROOT_DIR)/tos/lib/printf
CFLAGS += -DNEW_PRINTF_SEMANTICS


include $(TINYOS_ROOT_DIR)/Makefile.include

