#!/bin/bash

{{ script_remount }} rw

rsnapshot weekly

{{ script_remount }} ro
