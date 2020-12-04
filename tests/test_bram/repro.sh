#!/bin/bash

yosys -l yosys.log -p 'synth_ecp5 -abc9 -json build.json' repro.v 
