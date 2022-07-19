import std/net as stdNet
export stdNet

type
  ValidIpAddress* {.requiresInit.} = object
    value: IpAddress

when (NimMajor, NimMinor) < (1, 4):
  {.push raises: [Defect].}
else:
  {.push raises: [].}

proc ipv4*(address: array[4, byte]): ValidIpAddress =
  ValidIpAddress(value: IpAddress(family: IPv4, address_v4: address))

template ipv4*(a, b, c, d: byte): ValidIpAddress =
  ipv4([a, b, c, d])

proc ipv6*(address: array[16, byte]): ValidIpAddress =
  ValidIpAddress(value: IpAddress(family: IPv6, address_v6: address))

template family*(a: ValidIpAddress): IpAddressFamily =
  a.value.family

template address_v4*(a: ValidIpAddress): array[4, byte] =
  a.value.address_v4

template address_v6*(a: ValidIpAddress): array[16, byte] =
  a.value.address_v6

template `$`*(a: ValidIpAddress): string =
  $a.value

func init*(T: type ValidIpAddress, str: string): T
          {.raises: [ValueError].} =
  ValidIpAddress(value: stdNet.parseIpAddress(str))

func init*(T: type ValidIpAddress, ip: IpAddress): T =
  ValidIpAddress(value: ip)

converter toNormalIp*(ip: ValidIpAddress): IpAddress =
  ip.value

func default*(T: type ValidIpAddress): T {.error.}

