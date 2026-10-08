"""Virtual UDS ECU on vcan0. Listens on 0x7E0, answers on 0x7E8."""

REQ_ID, RES_ID = 0x7E0, 0x7E8
DIDS = {0x0101: [0x00, 0x28]}  # vehicle speed, 40 km/h


def main():
    # TODO(week 6): 0x22 ReadDataByIdentifier, NRC 0x11 / 0x13 / 0x31
    raise NotImplementedError


if __name__ == "__main__":
    main()
