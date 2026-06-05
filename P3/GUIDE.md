# Part 3 - Discovering BGP EVPN

## Objective

In this part we build a small EVPN fabric using:

* OSPF as the underlay network
* BGP EVPN as the control plane
* VXLAN VNI 10 as the overlay network
* Route Reflection (RR) to avoid a full mesh of BGP sessions

The topology is:

```text
                RR (_haitham-1)
                Lo: 1.1.1.1

               /      |      \
              /       |       \
             /        |        \
            /         |         \

      _haitham-2  _haitham-3  _haitham-4
      Lo:1.1.1.2 Lo:1.1.1.3 Lo:1.1.1.4

          |            |           |
        host1        host2       host3
```

The Route Reflector is only responsible for exchanging EVPN routes.

Traffic between hosts travels directly between VTEPs through VXLAN.

---

# 1 - Underlay Network Configuration

Before configuring BGP EVPN, we must ensure all routers can reach each other through OSPF.

---

## On Route Reflector (_haitham-1)

```bash
ip addr add 10.0.12.1/30 dev eth0
ip addr add 10.0.13.1/30 dev eth1
ip addr add 10.0.14.1/30 dev eth2

ip addr add 1.1.1.1/32 dev lo

ip link set eth0 up
ip link set eth1 up
ip link set eth2 up

echo 1 > /proc/sys/net/ipv4/ip_forward
```

---

## On Leaf 2 (_haitham-2)

```bash
ip addr add 10.0.12.2/30 dev eth0

ip addr add 1.1.1.2/32 dev lo

ip link set eth0 up
ip link set eth1 up

echo 1 > /proc/sys/net/ipv4/ip_forward
```

---

## On Leaf 3 (_haitham-3)

```bash
ip addr add 10.0.13.2/30 dev eth1

ip addr add 1.1.1.3/32 dev lo

ip link set eth0 up
ip link set eth1 up

echo 1 > /proc/sys/net/ipv4/ip_forward
```

---

## On Leaf 4 (_haitham-4)

```bash
ip addr add 10.0.14.2/30 dev eth2

ip addr add 1.1.1.4/32 dev lo

ip link set eth0 up
ip link set eth2 up

echo 1 > /proc/sys/net/ipv4/ip_forward
```

---

# 2 - OSPF Configuration

The purpose of OSPF is to advertise all loopbacks.

These loopbacks will later be used as VTEP addresses and BGP neighbor addresses.

---

## Route Reflector

```bash
vtysh
configure terminal

router ospf
 network 10.0.12.0/30 area 0
 network 10.0.13.0/30 area 0
 network 10.0.14.0/30 area 0
 network 1.1.1.1/32 area 0

 exit

exit
```

---

## Leaf 2

```bash
vtysh
configure terminal

router ospf
 network 10.0.12.0/30 area 0
 network 1.1.1.2/32 area 0

 exit

exit
```

---

## Leaf 3

```bash
vtysh
configure terminal

router ospf
 network 10.0.13.0/30 area 0
 network 1.1.1.3/32 area 0

 exit

exit
```

---

## Leaf 4

```bash
vtysh
configure terminal

router ospf
 network 10.0.14.0/30 area 0
 network 1.1.1.4/32 area 0

 exit

exit
```

---

# 3 - OSPF Verification

## On Route Reflector

```bash
vtysh
```

Verify neighbors:

```frr
show ip ospf neighbor
```

Expected:

```text
Neighbor ID     Pri State           Up Time         Dead Time Address         Interface                        RXmtL RqstL DBsmL
1.1.1.2           1 Full/Backup     2m23s             32.530s 10.0.12.2       eth0:10.0.12.1                       0     0     0
1.1.1.3           1 Full/Backup     1m35s             39.361s 10.0.13.2       eth1:10.0.13.1                       0     0     0
1.1.1.4           1 Full/Backup     56.773s           34.113s 10.0.14.2       eth2:10.0.14.1                       0     0     0
```

Verify routes:

```frr
show ip route
```

```text
Codes: K - kernel route, C - connected, L - local, S - static,
       R - RIP, O - OSPF, I - IS-IS, B - BGP, E - EIGRP, N - NHRP,
       T - Table, v - VNC, V - VNC-Direct, A - Babel, F - PBR,
       f - OpenFabric, t - Table-Direct,
       > - selected route, * - FIB route, q - queued, r - rejected, b - backup
       t - trapped, o - offload failure

IPv4 unicast VRF default:
O   1.1.1.1/32 [110/0] is directly connected, lo, weight 1, 00:08:24
L * 1.1.1.1/32 is directly connected, lo, weight 1, 00:15:22
C>* 1.1.1.1/32 is directly connected, lo, weight 1, 00:15:22
O>* 1.1.1.2/32 [110/10000] via 10.0.12.2, eth0, weight 1, 00:05:11
O>* 1.1.1.3/32 [110/10000] via 10.0.13.2, eth1, weight 1, 00:04:24
O>* 1.1.1.4/32 [110/10000] via 10.0.14.2, eth2, weight 1, 00:03:45
O   10.0.12.0/30 [110/10000] is directly connected, eth0, weight 1, 00:08:46
C>* 10.0.12.0/30 is directly connected, eth0, weight 1, 00:15:45
L>* 10.0.12.1/32 is directly connected, eth0, weight 1, 00:15:45
O   10.0.13.0/30 [110/10000] is directly connected, eth1, weight 1, 00:08:39
C>* 10.0.13.0/30 is directly connected, eth1, weight 1, 00:15:45
L>* 10.0.13.1/32 is directly connected, eth1, weight 1, 00:15:45
O   10.0.14.0/30 [110/10000] is directly connected, eth2, weight 1, 00:08:30
C>* 10.0.14.0/30 is directly connected, eth2, weight 1, 00:15:45
L>* 10.0.14.1/32 is directly connected, eth2, weight 1, 00:15:45
```
---

# 4 - Creating the VXLAN Overlay

The subject requires:

* VXLAN ID 10
* Bridge br0

Each leaf router acts as a VTEP.

---

## Leaf 2

```bash
ip link add br0 type bridge
ip link set br0 up

ip link add vxlan10 type vxlan \
id 10 \
local 1.1.1.2 \
dstport 4789 \
nolearning

ip link set vxlan10 up

ip link set eth1 master br0
ip link set vxlan10 master br0
```

---

## Leaf 3

```bash
ip link add br0 type bridge
ip link set br0 up

ip link add vxlan10 type vxlan \
id 10 \
local 1.1.1.3 \
dstport 4789 \
nolearning

ip link set vxlan10 up

ip link set eth0 master br0
ip link set vxlan10 master br0
```

---

## Leaf 4

```bash
ip link add br0 type bridge
ip link set br0 up

ip link add vxlan10 type vxlan \
id 10 \
local 1.1.1.4 \
dstport 4789 \
nolearning

ip link set vxlan10 up

ip link set eth0 master br0
ip link set vxlan10 master br0
```

---

# 5 - Route Reflector BGP EVPN Configuration

The Route Reflector only reflects EVPN routes.

---

## RR (_haitham-1)

```bash
vtysh
configure terminal
router bgp 65000
 bgp router-id 1.1.1.1

 neighbor 1.1.1.2 remote-as 65000
 neighbor 1.1.1.3 remote-as 65000
 neighbor 1.1.1.4 remote-as 65000

 neighbor 1.1.1.2 update-source lo
 neighbor 1.1.1.3 update-source lo
 neighbor 1.1.1.4 update-source lo

 address-family l2vpn evpn

  neighbor 1.1.1.2 activate
  neighbor 1.1.1.3 activate
  neighbor 1.1.1.4 activate

  neighbor 1.1.1.2 route-reflector-client
  neighbor 1.1.1.3 route-reflector-client
  neighbor 1.1.1.4 route-reflector-client

 exit-address-family
```

---

# 6 - Leaf BGP EVPN Configuration

## Leaf 2

```bash
vtysh
configure terminal
router bgp 65000
 bgp router-id 1.1.1.2

 neighbor 1.1.1.1 remote-as 65000
 neighbor 1.1.1.1 update-source lo

 address-family l2vpn evpn
  neighbor 1.1.1.1 activate
  advertise-all-vni
 exit-address-family
```

---

## Leaf 3

```bash
vtysh
configure terminal
router bgp 65000
 bgp router-id 1.1.1.3

 neighbor 1.1.1.1 remote-as 65000
 neighbor 1.1.1.1 update-source lo

 address-family l2vpn evpn
  neighbor 1.1.1.1 activate
  advertise-all-vni
 exit-address-family
```

---

## Leaf 4

```bash
vtysh
configure terminal
router bgp 65000
 bgp router-id 1.1.1.4

 neighbor 1.1.1.1 remote-as 65000
 neighbor 1.1.1.1 update-source lo

 address-family l2vpn evpn
  neighbor 1.1.1.1 activate
  advertise-all-vni
 exit-address-family
```

---

# 7 - BGP Verification

Check EVPN neighbors:

```bash
vtysh
show bgp l2vpn evpn summary
```

Expected:

```text
BGP router identifier 1.1.1.1, local AS number 65000 VRF default vrf-id 0
BGP table version 0
RIB entries 5, using 640 bytes of memory
Peers 3, using 50 KiB of memory

Neighbor        V         AS   MsgRcvd   MsgSent   TblVer  InQ OutQ  Up/Down State/PfxRcd   PfxSnt Desc
1.1.1.2         4      65000        24        24        3    0    0 00:12:17            1        3 FRRouting/10.5.3
1.1.1.3         4      65000        12        12        3    0    0 00:02:04            1        3 FRRouting/10.5.3
1.1.1.4         4      65000        10        11        3    0    0 00:00:37            1        3 FRRouting/10.5.3

Total number of neighbors 3
```

---

# 8 - EVPN Verification

Before any host becomes active:

```frr
show bgp l2vpn evpn
```

You should only see:

```text
BGP table version is 3, local router ID is 1.1.1.1
Status codes: s suppressed, d damped, h history, * valid, > best, i - internal
Origin codes: i - IGP, e - EGP, ? - incomplete
EVPN type-1 prefix: [1]:[EthTag]:[ESI]:[IPlen]:[VTEP-IP]:[Frag-id]
EVPN type-2 prefix: [2]:[EthTag]:[MAClen]:[MAC]:[IPlen]:[IP]
EVPN type-3 prefix: [3]:[EthTag]:[IPlen]:[OrigIP]
EVPN type-4 prefix: [4]:[ESI]:[IPlen]:[OrigIP]
EVPN type-5 prefix: [5]:[EthTag]:[IPlen]:[IP]

   Network          Next Hop            Metric LocPrf Weight Path
Route Distinguisher: 1.1.1.2:2
 *>i [3]:[0]:[32]:[1.1.1.2]
                    1.1.1.2                       100      0 i
                    RT:65000:10 ET:8
Route Distinguisher: 1.1.1.3:2
 *>i [3]:[0]:[32]:[1.1.1.3]
                    1.1.1.3                       100      0 i
                    RT:65000:10 ET:8
Route Distinguisher: 1.1.1.4:2
 *>i [3]:[0]:[32]:[1.1.1.4]
                    1.1.1.4                       100      0 i
                    RT:65000:10 ET:8

Displayed 3 out of 3 total prefixes
```

This matches the subject screenshots.

---

# 9 - Activate Host 1

Simply bring the interface up:

```bash
ip link set eth1 up
```

---

# 10 - Activate Host 2

```bash
ip link set eth0 up
```

---

# 11 - Activate Host 3

```bash
ip link set eth0 up
```

---

# 12 - Final Validation

Verify EVPN routes:

```frr
show bgp l2vpn evpn
```
