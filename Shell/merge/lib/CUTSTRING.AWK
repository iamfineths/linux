#!/bin/bash
#
###############################################
# FILE:         CUTSTRING.WAK
# PORPOSE:      截取端口
# AUTHOR:       handonglin
# DATE:         2014-08-27
###############################################

_CUT_STRINGS_()
{
        awk '
		BEGIN{
				FS="="
			}
			{
				if(/'${1}'/)
					{
						FIRST=$2
					}
			}
		END{
				print substr(FIRST,2,length(FIRST)-2)
			}' ${2}
}
