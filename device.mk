LOCAL_PATH := device/onyx/leaf3

PRODUCT_USE_DYNAMIC_PARTITIONS := true
# Stock OTAs are Virtual A/B payloads. This also lets recovery sideload use
# the complete super partition for a full payload rather than applying the
# conventional A/B half-super limit.
PRODUCT_VIRTUAL_AB_OTA := true
PRODUCT_SHIPPING_API_LEVEL := 30
PRODUCT_TARGET_VNDK_VERSION := 30

AB_OTA_UPDATER := true
AB_OTA_PARTITIONS += \
    abl \
    boot \
    dtbo \
    modem \
    product \
    recovery \
    system \
    system_ext \
    vbmeta \
    vbmeta_system \
    vendor \
    xbl

PRODUCT_PACKAGES += \
    fastbootd \
    tzdata_twrp

PRODUCT_SOONG_NAMESPACES += \
    $(LOCAL_PATH)

PRODUCT_COPY_FILES += \
    $(LOCAL_PATH)/recovery/root/init.recovery.qcom.rc:$(TARGET_COPY_OUT_RECOVERY)/root/init.recovery.qcom.rc \
    $(LOCAL_PATH)/recovery/root/system/etc/recovery.fstab:$(TARGET_COPY_OUT_RECOVERY)/root/system/etc/recovery.fstab \
    $(LOCAL_PATH)/recovery/root/waveform/eink_waveform.wbf:$(TARGET_COPY_OUT_RECOVERY)/root/waveform/eink_waveform.wbf

PRODUCT_PROPERTY_OVERRIDES += \
    ro.board.platform=bengal \
    ro.product.device=BOOX \
    ro.product.model=Leaf3 \
    ro.virtual_ab.enabled=true
