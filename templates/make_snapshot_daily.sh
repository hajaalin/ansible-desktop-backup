#!/bin/bash

{{ script_remount }} rw

rsnapshot daily

{{ script_remount }} ro
