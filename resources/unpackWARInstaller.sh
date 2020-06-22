#!/bin/bash

# Copyright (c) 2019. TIBCO Software Inc.
# This file is subject to the license terms contained
# in the license file that is distributed with this file.

unzip -o -q TIB_js-jrs_*.zip -d .
cd jasperreports-server-pro-*-bin
unzip -o -q jasperserver-pro.war -d jasperserver-pro
