######################################################
#                                                    #
#  Silicon Perspective, A Cadence Company            #
#  FirstEncounter IO Assignment                      #
#                                                    #
######################################################

Version: 2

#Example:  
#Pad: I_CLK 		W

#define your iopad location here

Pad: I_RESET         W
Pad: I_CLK           W
Pad: I_IN_VALID      W
Pad: I_IN_VALID2     W
Pad: I_MATRIX        S
Pad: I_MATRIX_SIZE_0 S
Pad: I_MATRIX_SIZE_1 S
Pad: I_I_MAT_IDX     S
Pad: I_W_MAT_IDX     S
Pad: O_OUT_VALID     E
Pad: O_OUT_VALUE     E

Pad: VDDP0           N
Pad: GNDP0           N

Pad: VDDC0           N
Pad: GNDC0           N

Pad: VDDP1           N
Pad: GNDP1           N
Pad: VDDP2           E
Pad: GNDP2           E


Pad: VDDC1           W
Pad: GNDC1           W
Pad: VDDC2           E
Pad: GNDC2           E
Pad: VDDC3           S
Pad: GNDC3           S

Pad: PCLR SE PCORNER
Pad: PCUL NW PCORNER
Pad: PCUR NE PCORNER
Pad: PCLL SW PCORNER
