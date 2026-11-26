# How Precision X1 handles the iCX3 MCU

Behaviour of Precision X1 1.3.6.0 / 1.3.7.0 with EVGA RTX 30 cards, as relevant for MCU repairs.

## Start-up

1. For every NVIDIA GPU whose PCI subsystem vendor is `0x3842`, it creates an MCU controller on I2C
   port 1, address `0x5A` (see [i2c-protocol.md](i2c-protocol.md)).
2. The controller counts as "initialised" as soon as one ReadInformation transaction succeeds at the
   I2C level, even when the data are not valid.
3. Only when the reply is valid (`05 FC ...`) does it select the product-specific routines (fan,
   thermistor, voltage, LED handlers). With an invalid reply those routines stay unset.
4. The hardware-monitor page then asks the MCU for the iCX thermistor temperatures through one of those
   unset routines → `NullReferenceException` in `PX18.Monitors.RTX30.iCX3ExtTemp..ctor` and the
   application exits. That is the crash you see in Event Viewer.

So "PX1 closes on start with `iCX3ExtTemp` in the stack" means: the MCU answers on the bus but its
identification is not readable at the speed PX1 uses (or the MCU is not an iCX3 MCU at all).

## Firmware check

After the MCU is read correctly, PX1 compares it with an internal table indexed by the card's PCI
subsystem ID (the second half of `3842:xxxx`), see [ssid-firmware-map.md](ssid-firmware-map.md):

- Same ProductID as the table entry → it offers an update only if the MCU version is older.
- Different ProductID but in the same product group → it forces the table's image. For the LPC51U68
  FTW3/XC3 family the groups are `{160, 2, 4, 8, 9}` (FTW3 variants + bootloader) and
  `{160, 1, 5, 6, 7}` (XC3 variants + bootloader).
- Different group → it shows "A system restart is needed to install the correct firmware update" and
  reboots.

When it decides to update, it starts
`Library\FirmwareUpdate.exe --gpu N --fullname "<PX1>\Firmware\<image>" --return "<PX1>\PrecisionX_x64.exe"`
and **exits immediately**. That looks like "PX1 opened for a second and closed", without any error.
The command line of the FirmwareUpdate process tells you which image PX1 wants for that board.

## FirmwareUpdate.exe

- Arguments come in pairs (`--key value`); the image path must exist.
- It uses the same `ManagedNvApi.dll` as PX1 (the copy in `Library\`), so it suffers the same I2C speed
  problem.
- It shows only "Firmware update failed" and hides the status code; see the list in
  [i2c-protocol.md](i2c-protocol.md#updater-status-codes).

## EVGA MCU Tool (third-party)

The community "EVGA MCU Tool" is only a front end: it lists the images of a Precision X1 version,
shows their ProductID and launches `FirmwareUpdate.exe --gpu N --fullname <path> --return <PX1 path>`.
It passes the paths **without quotes**, so the tool must live in a folder without spaces in its path.
It cannot do anything FirmwareUpdate cannot.

## Uninstalling

`uninstall.exe /S` also launches "EVGA Precision for Game Bar Installer" in the desktop session and
waits for it. Remove the widget with
`Get-AppxPackage -AllUsers *EVGAPrecisionGamebar* | Remove-AppxPackage -AllUsers`. A kernel driver file
can remain in `C:\Program Files (x86)\EVGA\Kernel`.
