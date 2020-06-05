import std/net as stdNet
export stdNet

type
  ValidIpAddress* = distinct IpAddress

{.push raises: [Defect].}

proc ipv4*(address: array[4, byte]): ValidIpAddress =
  ValidIpAddress IpAddress(family: IPv4, address_v4: address)

template ipv4*(a, b, c, d: byte): ValidIpAddress =
  ipv4([a, b, c, d])

proc ipv6*(address: array[16, byte]): ValidIpAddress =
  ValidIpAddress IpAddress(family: IPv6, address_v6: address)

template family*(a: ValidIpAddress): IpAddressFamily =
  IpAddress(a).family

template address_v4*(a: ValidIpAddress): array[4, byte] =
  IpAddress(a).address_v4

template address_v6*(a: ValidIpAddress): array[16, byte] =
  IpAddress(a).address_v6

template `$`*(a: ValidIpAddress): string =
  $ IpAddress(a)

func init*(T: type ValidIpAddress, str: string): T
          {.raises: [ValueError].} =
  ValidIpAddress stdNet.parseIpAddress(str)

