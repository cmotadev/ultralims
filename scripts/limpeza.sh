#!/bin/bash

# Rotina de Limpeza

ULTRALIMS_DATA=/var/www/html/empresas/
DIAS_RETENCAO=3

find $ULTRALIMS_DATA/error/ -atime +$DIAS_RETENCAO -exec rm \{\} \;
find $ULTRALIMS_DATA/log/ -atime +$DIAS_RETENCAO -exec rm \{\} \;
find $ULTRALIMS_DATA/200/log/ -atime +$DIAS_RETENCAO -exec rm \{\} \;
find $ULTRALIMS_DATA/200/login/ -atime +$DIAS_RETENCAO -exec rm \{\} \;
find $ULTRALIMS_DATA/200/temp/ -atime +$DIAS_RETENCAO -exec rm \{\} \;
find /var/www/html/logs/ -atime +$DIAS_RETENCAO -exec rm \{\} \;
