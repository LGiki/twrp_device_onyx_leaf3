LOCAL_PATH := $(call my-dir)

ifeq ($(TARGET_DEVICE),leaf3)
include $(call all-subdir-makefiles,$(LOCAL_PATH))
endif

