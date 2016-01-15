#!/bin/bash

{{ script_remount }} rw

[ "$(date '+\%a')" = "Wed" ] && rsnapshot monthly

{{ script_remount }} ro
