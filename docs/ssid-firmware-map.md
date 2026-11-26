# Board subsystem ID → MCU firmware (Precision X1 1.3.7.0)

Precision X1 decides which iCX3 MCU image a card needs from the card's **PCI subsystem ID**
(`3842:xxxx`, visible in GPU-Z, Device Manager → Hardware IDs `SUBSYS_xxxx3842`, or `nvidia-smi
--query-gpu=pci.sub_device_id --format=csv`). This is the table built into Precision X1 1.3.7.0, the
last release (its images are identical to 1.3.6.0's).

When an SSID lists two images, Precision X1 walks them in order and picks the first one whose
ProductID is in the same product group as what the MCU currently reports: in practice the
`..._LPC54113_...` / `..._STM32L431_...` images are for boards built with those MCUs, and the plain
`..._Rxxx.bin` images for the LPC51U68. Check which chip your board has.

Example from the repair this repository comes from: `3842:3982` (RTX 3090 FTW3 Ultra) with an LPC51U68
needs `FTW_3Fans_AP_R122.bin` (ProductID 2). `FTW_E230_3Fans_376x_AP_R110.bin` is only listed for the
`3842:376x` boards; flashing it on a `3982` board works electrically, but Precision X1 will keep asking
to replace it.

Image files are in `C:\Program Files\EVGA\Precision X1\Firmware\`. Version shown as major.minor
(`R122` = 1.22).

| Subsystem ID | Firmware image(s) (ProductID, version) |
|---|---|
| 3842:3221 | XC_3Fans_AP_LPC54113_V100.bin (ID 17, v1.0) |
| 3842:3225 | XC_3Fans_AP_LPC54113_V100.bin (ID 17, v1.0) |
| 3842:3281 | XC_3Fans_AP_STM32L431_V100.bin (ID 33, v1.0) |
| 3842:3285 | XC_3Fans_AP_STM32L431_V100.bin (ID 33, v1.0) |
| 3842:3295 | FTW_3Fans_AP_LPC54113_V100.bin (ID 18, v1.0) |
| 3842:3297 | FTW_3Fans_AP_LPC54113_V100.bin (ID 18, v1.0) |
| 3842:3298 | FTW_E227_E228_Hybrid_AP_LPC54113_V103.bin (ID 24, v1.3) |
| 3842:3321 | XC_3Fans_AP_LPC54113_V100.bin (ID 17, v1.0) |
| 3842:3323 | XC_3Fans_AP_LPC54113_V100.bin (ID 17, v1.0) |
| 3842:3325 | XC_3Fans_AP_LPC54113_V100.bin (ID 17, v1.0) |
| 3842:3351 | XC_3Fans_AP_STM32L431_V100.bin (ID 33, v1.0) |
| 3842:3353 | XC_3Fans_AP_STM32L431_V100.bin (ID 33, v1.0) |
| 3842:3355 | XC_3Fans_AP_STM32L431_V100.bin (ID 33, v1.0) |
| 3842:3365 | FTW_3Fans_AP_LPC54113_V100.bin (ID 18, v1.0) |
| 3842:3367 | FTW_3Fans_AP_LPC54113_V100.bin (ID 18, v1.0) |
| 3842:3368 | FTW_E227_E228_Hybrid_AP_LPC54113_V103.bin (ID 24, v1.3) |
| 3842:3371 | XC_3Fans_AP_STM32L431_V100.bin (ID 33, v1.0) |
| 3842:3373 | XC_3Fans_AP_STM32L431_V100.bin (ID 33, v1.0) |
| 3842:3375 | XC_3Fans_AP_STM32L431_V100.bin (ID 33, v1.0) |
| 3842:3385 | FTW_3Fans_AP_LPC54113_V100.bin (ID 18, v1.0) |
| 3842:3387 | FTW_3Fans_AP_LPC54113_V100.bin (ID 18, v1.0) |
| 3842:3388 | FTW_E227_E228_Hybrid_AP_LPC54113_V103.bin (ID 24, v1.3) |
| 3842:3411 | XC_E229_E237_LPC54113_AP_V101.bin (ID 21, v1.1) |
| 3842:3413 | XC_E229_E237_LPC54113_AP_V101.bin (ID 21, v1.1) |
| 3842:3415 | XC_E229_E237_LPC54113_AP_V101.bin (ID 21, v1.1) |
| 3842:3425 | FTW_E230_3Fans_376x_LPC54113_AP_V101.bin (ID 20, v1.1) |
| 3842:3427 | FTW_E230_3Fans_376x_LPC54113_AP_V101.bin (ID 20, v1.1) |
| 3842:3451 | XC_E229_E237_LPC54113_AP_V101.bin (ID 21, v1.1)<br>XC_E229_E237_STM32L431_AP_V100.bin (ID 37, v1.0) |
| 3842:3453 | XC_E229_E237_LPC54113_AP_V101.bin (ID 21, v1.1)<br>XC_E229_E237_STM32L431_AP_V100.bin (ID 37, v1.0) |
| 3842:3455 | XC_E229_E237_LPC54113_AP_V101.bin (ID 21, v1.1)<br>XC_E229_E237_STM32L431_AP_V100.bin (ID 37, v1.0) |
| 3842:3465 | FTW_E238_3Fans_376x_AP_STM32L431_V101.bin (ID 36, v1.1)<br>FTW_E230_3Fans_376x_LPC54113_AP_V101.bin (ID 20, v1.1) |
| 3842:3467 | FTW_E238_3Fans_376x_AP_STM32L431_V101.bin (ID 36, v1.1)<br>FTW_E230_3Fans_376x_LPC54113_AP_V101.bin (ID 20, v1.1) |
| 3842:3481 | XC_E229_E237_STM32L431_AP_V100.bin (ID 37, v1.0) |
| 3842:3483 | XC_E229_E237_STM32L431_AP_V100.bin (ID 37, v1.0) |
| 3842:3485 | XC_E229_E237_STM32L431_AP_V100.bin (ID 37, v1.0) |
| 3842:3495 | FTW_E238_3Fans_376x_AP_STM32L431_V101.bin (ID 36, v1.1) |
| 3842:3497 | FTW_E238_3Fans_376x_AP_STM32L431_V101.bin (ID 36, v1.1) |
| 3842:3523 | XC_3Fans_AP_LPC54113_V100.bin (ID 17, v1.0) |
| 3842:3562 | XC_E229_E237_LPC54113_AP_V101.bin (ID 21, v1.1)<br>XC_E229_E237_STM32L431_AP_V100.bin (ID 37, v1.0) |
| 3842:3565 | XC_E229_E237_LPC54113_AP_V101.bin (ID 21, v1.1)<br>XC_E229_E237_STM32L431_AP_V100.bin (ID 37, v1.0) |
| 3842:3567 | XC_E229_E237_LPC54113_AP_V101.bin (ID 21, v1.1)<br>XC_E229_E237_STM32L431_AP_V100.bin (ID 37, v1.0) |
| 3842:3583 | XC_3Fans_AP_STM32L431_V100.bin (ID 33, v1.0) |
| 3842:3662 | XC_E229_3Fans_375x_AP_R107.bin (ID 5, v1.7) |
| 3842:3665 | XC_E229_3Fans_375x_AP_R107.bin (ID 5, v1.7) |
| 3842:3667 | XC_E229_3Fans_375x_AP_R107.bin (ID 5, v1.7) |
| 3842:3751 | XC_E229_3Fans_375x_AP_R107.bin (ID 5, v1.7) |
| 3842:3753 | XC_E229_3Fans_375x_AP_R107.bin (ID 5, v1.7) |
| 3842:3755 | XC_E229_3Fans_375x_AP_R107.bin (ID 5, v1.7) |
| 3842:3765 | FTW_E230_3Fans_376x_AP_R110.bin (ID 4, v1.10) |
| 3842:3767 | FTW_E230_3Fans_376x_AP_R110.bin (ID 4, v1.10) |
| 3842:3781 | XC_E229_3Fans_375x_AP_R107.bin (ID 5, v1.7) |
| 3842:3783 | XC_E229_E237_STM32L431_AP_V100.bin (ID 37, v1.0)<br>XC_E229_3Fans_375x_AP_R107.bin (ID 5, v1.7) |
| 3842:3785 | XC_E229_3Fans_375x_AP_R107.bin (ID 5, v1.7) |
| 3842:3795 | FTW_E230_3Fans_376x_AP_R110.bin (ID 4, v1.10) |
| 3842:3797 | FTW_E238_3Fans_376x_AP_STM32L431_V101.bin (ID 36, v1.1)<br>FTW_E230_3Fans_376x_AP_R110.bin (ID 4, v1.10) |
| 3842:3881 | XC_E221_3Fans_AP_R117.bin (ID 1, v1.17) |
| 3842:3883 | XC_E221_3Fans_AP_R117.bin (ID 1, v1.17) |
| 3842:3885 | XC_E221_3Fans_AP_R117.bin (ID 1, v1.17) |
| 3842:3888 | XC_Hybrid_AP_R108.bin (ID 6, v1.8) |
| 3842:3889 | XC_HC_AP_R109.bin (ID 7, v1.9) |
| 3842:3895 | FTW_3Fans_AP_R122.bin (ID 2, v1.22) |
| 3842:3897 | FTW_3Fans_AP_R122.bin (ID 2, v1.22) |
| 3842:3898 | FTW_E227_Hybrid_AP_R110.bin (ID 8, v1.10) |
| 3842:3899 | FTW_HC_AP_R110.bin (ID 9, v1.10) |
| 3842:3951 | XC_E221_3Fans_AP_R117.bin (ID 1, v1.17) |
| 3842:3953 | XC_E221_3Fans_AP_R117.bin (ID 1, v1.17) |
| 3842:3955 | XC_E221_3Fans_AP_R117.bin (ID 1, v1.17) |
| 3842:3958 | XC_Hybrid_AP_R108.bin (ID 6, v1.8) |
| 3842:3959 | XC_HC_AP_R109.bin (ID 7, v1.9) |
| 3842:3965 | FTW_3Fans_AP_R122.bin (ID 2, v1.22) |
| 3842:3967 | FTW_3Fans_AP_R122.bin (ID 2, v1.22) |
| 3842:3968 | FTW_E227_Hybrid_AP_R110.bin (ID 8, v1.10) |
| 3842:3969 | FTW_HC_AP_R110.bin (ID 9, v1.10) |
| 3842:3971 | XC_E221_3Fans_AP_R117.bin (ID 1, v1.17) |
| 3842:3973 | XC_E221_3Fans_AP_R117.bin (ID 1, v1.17) |
| 3842:3975 | XC_E221_3Fans_AP_R117.bin (ID 1, v1.17) |
| 3842:3978 | XC_Hybrid_AP_R108.bin (ID 6, v1.8) |
| 3842:3979 | XC_HC_AP_R109.bin (ID 7, v1.9) |
| 3842:3981 | FTW_3Fans_AP_R122.bin (ID 2, v1.22) |
| 3842:3982 | FTW_3Fans_AP_LPC54113_V100.bin (ID 18, v1.0)<br>FTW_3Fans_AP_R122.bin (ID 2, v1.22) |
| 3842:3983 | FTW_E227_Hybrid_AP_R110.bin (ID 8, v1.10) |
| 3842:3985 | FTW_3Fans_AP_R122.bin (ID 2, v1.22) |
| 3842:3986 | FTW_HC_AP_R110.bin (ID 9, v1.10) |
| 3842:3987 | FTW_3Fans_AP_R122.bin (ID 2, v1.22) |
| 3842:3988 | FTW_E227_Hybrid_AP_R110.bin (ID 8, v1.10) |
| 3842:3989 | FTW_HC_AP_R110.bin (ID 9, v1.10) |
| 3842:3998 | KingPin_E223_HC_Hybird_AP_R133.bin (ID 3, v1.33) |
| 3842:3999 | KINGPIN_HC_AP_R109.bin (ID 10, v1.9) |
| 3842:4221 | XC_3Fans_AP_LPC54113_V100.bin (ID 17, v1.0) |
| 3842:4223 | XC_3Fans_AP_LPC54113_V100.bin (ID 17, v1.0) |
| 3842:4225 | XC_3Fans_AP_LPC54113_V100.bin (ID 17, v1.0) |
| 3842:4231 | XC_3Fans_AP_LPC54113_V100.bin (ID 17, v1.0) |
| 3842:4233 | XC_3Fans_AP_LPC54113_V100.bin (ID 17, v1.0) |
| 3842:4235 | XC_3Fans_AP_LPC54113_V100.bin (ID 17, v1.0) |
| 3842:4261 | XC_3Fans_AP_STM32L431_V100.bin (ID 33, v1.0) |
| 3842:4263 | XC_3Fans_AP_STM32L431_V100.bin (ID 33, v1.0) |
| 3842:4265 | XC_3Fans_AP_STM32L431_V100.bin (ID 33, v1.0) |
| 3842:4275 | FTW_3Fans_AP_LPC54113_V100.bin (ID 18, v1.0) |
| 3842:4277 | FTW_3Fans_AP_LPC54113_V100.bin (ID 18, v1.0) |
| 3842:4278 | FTW_E227_E228_Hybrid_AP_LPC54113_V103.bin (ID 24, v1.3) |
| 3842:4281 | XC_3Fans_AP_STM32L431_V100.bin (ID 33, v1.0) |
| 3842:4283 | XC_3Fans_AP_STM32L431_V100.bin (ID 33, v1.0) |
| 3842:4285 | XC_3Fans_AP_STM32L431_V100.bin (ID 33, v1.0) |
| 3842:4295 | FTW_3Fans_AP_LPC54113_V100.bin (ID 18, v1.0) |
| 3842:4297 | FTW_3Fans_AP_LPC54113_V100.bin (ID 18, v1.0) |
| 3842:4298 | FTW_E227_E228_Hybrid_AP_LPC54113_V103.bin (ID 24, v1.3) |
| 3842:4451 | XC_E229_E237_LPC54113_AP_V101.bin (ID 21, v1.1)<br>XC_E229_E237_STM32L431_AP_V100.bin (ID 37, v1.0) |
| 3842:4453 | XC_E229_E237_LPC54113_AP_V101.bin (ID 21, v1.1)<br>XC_E229_E237_STM32L431_AP_V100.bin (ID 37, v1.0) |
| 3842:4455 | XC_E229_E237_LPC54113_AP_V101.bin (ID 21, v1.1)<br>XC_E229_E237_STM32L431_AP_V100.bin (ID 37, v1.0) |
| 3842:4465 | FTW_E238_3Fans_376x_AP_STM32L431_V101.bin (ID 36, v1.1)<br>FTW_E230_3Fans_376x_LPC54113_AP_V101.bin (ID 20, v1.1) |
| 3842:4467 | FTW_E238_3Fans_376x_AP_STM32L431_V101.bin (ID 36, v1.1)<br>FTW_E230_3Fans_376x_LPC54113_AP_V101.bin (ID 20, v1.1) |
| 3842:4471 | XC_E229_E237_STM32L431_AP_V100.bin (ID 37, v1.0) |
| 3842:4473 | XC_E229_E237_STM32L431_AP_V100.bin (ID 37, v1.0) |
| 3842:4475 | XC_E229_E237_STM32L431_AP_V100.bin (ID 37, v1.0) |
| 3842:4485 | FTW_E238_3Fans_376x_AP_STM32L431_V101.bin (ID 36, v1.1) |
| 3842:4487 | FTW_E238_3Fans_376x_AP_STM32L431_V101.bin (ID 36, v1.1) |
| 3842:4565 | XC_E229_E237_LPC54113_AP_V101.bin (ID 21, v1.1)<br>XC_E229_E237_STM32L431_AP_V100.bin (ID 37, v1.0) |
| 3842:4567 | XC_E229_E237_LPC54113_AP_V101.bin (ID 21, v1.1)<br>XC_E229_E237_STM32L431_AP_V100.bin (ID 37, v1.0) |
| 3842:4665 | XC_E229_3Fans_375x_AP_R107.bin (ID 5, v1.7) |
| 3842:4667 | XC_E229_3Fans_375x_AP_R107.bin (ID 5, v1.7) |
| 3842:4751 | XC_E229_3Fans_375x_AP_R107.bin (ID 5, v1.7) |
| 3842:4753 | XC_E229_3Fans_375x_AP_R107.bin (ID 5, v1.7) |
| 3842:4755 | XC_E229_E237_STM32L431_AP_V100.bin (ID 37, v1.0)<br>XC_E229_3Fans_375x_AP_R107.bin (ID 5, v1.7) |
| 3842:4765 | FTW_E230_3Fans_376x_AP_R110.bin (ID 4, v1.10) |
| 3842:4767 | FTW_E230_3Fans_376x_LPC54113_AP_V101.bin (ID 20, v1.1)<br>FTW_E230_3Fans_376x_AP_R110.bin (ID 4, v1.10) |
| 3842:4771 | XC_E229_3Fans_375x_AP_R107.bin (ID 5, v1.7) |
| 3842:4773 | XC_E229_3Fans_375x_AP_R107.bin (ID 5, v1.7) |
| 3842:4775 | XC_E229_3Fans_375x_AP_R107.bin (ID 5, v1.7) |
| 3842:4785 | FTW_E230_3Fans_376x_AP_R110.bin (ID 4, v1.10) |
| 3842:4787 | FTW_E230_3Fans_376x_AP_R110.bin (ID 4, v1.10) |
| 3842:4861 | XC_E221_3Fans_AP_R117.bin (ID 1, v1.17) |
| 3842:4863 | XC_E221_3Fans_AP_R117.bin (ID 1, v1.17) |
| 3842:4865 | XC_E221_3Fans_AP_R117.bin (ID 1, v1.17) |
| 3842:4868 | XC_Hybrid_AP_R108.bin (ID 6, v1.8) |
| 3842:4869 | XC_HC_AP_R109.bin (ID 7, v1.9) |
| 3842:4875 | FTW_3Fans_AP_R122.bin (ID 2, v1.22) |
| 3842:4877 | FTW_3Fans_AP_R122.bin (ID 2, v1.22) |
| 3842:4878 | FTW_E227_Hybrid_AP_R110.bin (ID 8, v1.10) |
| 3842:4879 | FTW_HC_AP_R110.bin (ID 9, v1.10) |
| 3842:4881 | XC_E221_3Fans_AP_R117.bin (ID 1, v1.17) |
| 3842:4883 | XC_E221_3Fans_AP_R117.bin (ID 1, v1.17) |
| 3842:4885 | XC_E221_3Fans_AP_R117.bin (ID 1, v1.17) |
| 3842:4888 | XC_Hybrid_AP_R108.bin (ID 6, v1.8) |
| 3842:4889 | XC_HC_AP_R109.bin (ID 7, v1.9) |
| 3842:4895 | FTW_3Fans_AP_R122.bin (ID 2, v1.22) |
| 3842:4897 | FTW_3Fans_AP_R122.bin (ID 2, v1.22) |
| 3842:4898 | FTW_E227_Hybrid_AP_R110.bin (ID 8, v1.10) |
| 3842:4899 | FTW_HC_AP_R110.bin (ID 9, v1.10) |
| 3842:4981 | iCX3_FTW_E250_AP_V109.bin (ID 50, v1.9) |
| 3842:4983 | iCX3_FTW_E250_AP_V109.bin (ID 50, v1.9) |
| 3842:4985 | iCX3_FTW_E250_AP_V109.bin (ID 50, v1.9) |
| 3842:4988 | iCX3_FTW_E250_Hybird_AP_V106.bin (ID 56, v1.6) |
| 3842:4998 | iCX3_KingPin_E251_AP_V114.bin (ID 19, v1.14) |
