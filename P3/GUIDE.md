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

### Purpose
Configure the Route Reflector underlay interfaces and its loopback address, and enable kernel forwarding so the router can carry OSPF and later BGP traffic.

### Command Breakdown
* `ip addr add` assigns an IP address to an interface.
* `10.0.12.1/30`, `10.0.13.1/30`, `10.0.14.1/30` set point-to-point underlay addresses to each neighbor-facing interface.
* `1.1.1.1/32 dev lo` creates the loopback address used as the BGP router ID and VTEP source address.
* `ip link set <iface> up` activates the physical interface.
* `echo 1 > /proc/sys/net/ipv4/ip_forward` enables IPv4 routing through the Linux kernel.

### Result
The Route Reflector has its underlay links and loopback configured, allowing it to form OSPF adjacencies with leaves and forward routed traffic across the topology.

---

## On Leaf 2 (_haitham-2)

```bash
ip addr add 10.0.12.2/30 dev eth0

ip addr add 1.1.1.2/32 dev lo

ip link set eth0 up
ip link set eth1 up

echo 1 > /proc/sys/net/ipv4/ip_forward
```

### Purpose
Configure Leaf 2 with its underlay neighbor address toward the Route Reflector and its loopback address, then enable forwarding so it can participate in OSPF.

### Command Breakdown
* `10.0.12.2/30 dev eth0` assigns the point-to-point underlay address on Leaf 2’s uplink interface.
* `1.1.1.2/32 dev lo` creates the leaf loopback used as its BGP/VTEP identifier.
* `ip link set eth0 up` and `ip link set eth1 up` bring the leaf's interfaces online.
* `echo 1 > /proc/sys/net/ipv4/ip_forward` allows the host to route packets between interfaces.

### Result
Leaf 2 can reach the Route Reflector over the underlay network and advertises its loopback into OSPF once the routing daemon is configured.

---

## On Leaf 3 (_haitham-3)

```bash
ip addr add 10.0.13.2/30 dev eth1

ip addr add 1.1.1.3/32 dev lo

ip link set eth0 up
ip link set eth1 up

echo 1 > /proc/sys/net/ipv4/ip_forward
```

### Purpose
Configure Leaf 3 with its underlay neighbor address, loopback address, and interface activation so it can join the OSPF underlay.

### Command Breakdown
* `10.0.13.2/30 dev eth1` assigns Leaf 3’s underlay address toward the Route Reflector.
* `1.1.1.3/32 dev lo` sets the leaf loopback used for BGP neighbor and VTEP identification.
* `ip link set eth0 up` and `ip link set eth1 up` enable the leaf’s interfaces.
* `echo 1 > /proc/sys/net/ipv4/ip_forward` enables packet forwarding in the Linux kernel.

### Result
Leaf 3 can establish reachability with the Route Reflector over the OSPF underlay and later advertise its local loopback.

---

## On Leaf 4 (_haitham-4)

```bash
ip addr add 10.0.14.2/30 dev eth2

ip addr add 1.1.1.4/32 dev lo

ip link set eth0 up
ip link set eth2 up

echo 1 > /proc/sys/net/ipv4/ip_forward
```

### Purpose
Configure Leaf 4 with its underlay link to the Route Reflector, its loopback address, and enable IPv4 forwarding for OSPF.

### Command Breakdown
* `10.0.14.2/30 dev eth2` sets the underlay address on Leaf 4’s uplink interface.
* `1.1.1.4/32 dev lo` assigns the loopback address used for the BGP session and VXLAN endpoint.
* `ip link set eth0 up` and `ip link set eth2 up` activate the relevant interfaces.
* `echo 1 > /proc/sys/net/ipv4/ip_forward` enables the device to forward IPv4 traffic between interfaces.

### Result
Leaf 4 is prepared to exchange OSPF hellos and advertise its loopback as part of the underlay network.

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

### Purpose
Enter the FRR configuration shell and enable OSPF on the Route Reflector so it advertises all underlay links and its loopback.

### Command Breakdown
* `vtysh` launches the FRR integrated command shell.
* `configure terminal` enters global configuration mode.
* `router ospf` starts OSPF configuration.
* `network ... area 0` advertises each subnet into OSPF within area 0.
* `exit` leaves configuration modes.

### Result
The Route Reflector begins advertising its directly connected underlay networks and loopback to other OSPF routers, allowing the underlay topology to converge.

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

### Purpose
Enter FRR configuration mode on Leaf 2 and enable OSPF so the leaf advertises its underlay link and loopback into the shared area.

### Command Breakdown
* `router ospf` begins OSPF configuration.
* `network 10.0.12.0/30 area 0` advertises the point-to-point underlay subnet to the OSPF domain.
* `network 1.1.1.2/32 area 0` advertises the leaf loopback address used for BGP and VTEP reachability.

### Result
Leaf 2 injects its underlay and loopback routes into OSPF, allowing the Route Reflector and other leaves to learn the leaf’s address.

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

### Purpose
Enter FRR configuration on Leaf 3 and advertise the leaf’s underlay and loopback addresses into OSPF.

### Command Breakdown
* `router ospf` starts OSPF configuration in FRR.
* `network 10.0.13.0/30 area 0` advertises the underlay link to the Route Reflector.
* `network 1.1.1.3/32 area 0` advertises Leaf 3’s loopback into the OSPF area.

### Result
Leaf 3 becomes reachable through the OSPF underlay and its loopback is known for later BGP EVPN neighbor formation.

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

### Purpose
Enter FRR configuration on Leaf 4 and advertise its underlay link and loopback into OSPF so it can join the fabric.

### Command Breakdown
* `router ospf` begins the OSPF configuration mode.
* `network 10.0.14.0/30 area 0` advertises Leaf 4’s underlay subnet.
* `network 1.1.1.4/32 area 0` advertises the leaf’s loopback address used for BGP neighbor establishment.

### Result
Leaf 4’s underlay and loopback addresses are propagated into the OSPF topology, enabling full reachability among the routers.

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

### Purpose
Open the FRR shell and query OSPF neighbor state to verify that the underlay adjacencies are established.

### Command Breakdown
* `vtysh` launches the FRR unified shell.
* `show ip ospf neighbor` displays OSPF neighbor relationships, including state and interface information.

### Result
You can confirm that the Route Reflector has formed full OSPF adjacencies with each leaf and that the underlay is operational.


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

### Purpose
Inspect the routing table to confirm that OSPF has learned loopback and underlay routes from all routers.

### Command Breakdown
* `show ip route` displays the IPv4 routing table in FRR.

### Result
The output verifies OSPF convergence by showing learned loopback prefixes and directly connected underlay networks.

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

### Purpose
Create the VXLAN overlay bridge and VTEP on Leaf 2 so Ethernet traffic can be encapsulated and forwarded over the underlay.

### Command Breakdown
* `ip link add br0 type bridge` creates a Linux bridge called `br0`.
* `ip link set br0 up` activates the bridge.
* `ip link add vxlan10 type vxlan` creates a VXLAN device with the name `vxlan10`.
* `id 10` sets the VXLAN Network Identifier to 10.
* `local 1.1.1.2` binds the VXLAN source to Leaf 2’s loopback/VTEP address.
* `dstport 4789` uses the standard VXLAN UDP destination port.
* `nolearning` disables MAC learning on the VXLAN interface so EVPN controls MAC reachability.
* `ip link set vxlan10 up` activates the VXLAN device.
* `ip link set eth1 master br0` attaches the local host-facing interface to the bridge.
* `ip link set vxlan10 master br0` attaches the VXLAN interface to the same bridge.

### Result
Leaf 2 now has a VXLAN VTEP attached to `br0`, allowing local host traffic to be encapsulated into VXLAN packets for the EVPN fabric.

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

### Purpose
Create the VXLAN bridge and VTEP on Leaf 3 so the leaf can participate in the EVPN overlay for VNI 10.

### Command Breakdown
* `ip link add br0 type bridge` creates the bridge device `br0`.
* `ip link set br0 up` brings the bridge online.
* `ip link add vxlan10 type vxlan` creates the VXLAN interface named `vxlan10`.
* `id 10` selects VXLAN VNI 10.
* `local 1.1.1.3` uses Leaf 3’s loopback address as the VXLAN source address.
* `dstport 4789` configures the VXLAN UDP encapsulation port.
* `nolearning` prevents the VXLAN interface from learning MAC addresses locally.
* `ip link set vxlan10 up` activates the VXLAN interface.
* `ip link set eth0 master br0` attaches the host-facing interface to the bridge.
* `ip link set vxlan10 master br0` attaches the VXLAN tunnel to the bridge.

### Result
Leaf 3 is ready to forward local host traffic into the VXLAN overlay and to receive VXLAN traffic from the fabric.

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

### Purpose
Build the VXLAN bridge and VTEP on Leaf 4, enabling it to encapsulate local traffic into the overlay network.

### Command Breakdown
* `ip link add br0 type bridge` creates a bridge interface named `br0`.
* `ip link set br0 up` activates the bridge.
* `ip link add vxlan10 type vxlan` creates the VXLAN tunnel interface.
* `id 10` specifies the VXLAN network identifier.
* `local 1.1.1.4` binds the VXLAN tunnel to Leaf 4’s loopback address.
* `dstport 4789` uses the VXLAN UDP port for encapsulation.
* `nolearning` disables local MAC learning on the tunnel interface.
* `ip link set vxlan10 up` enables the VXLAN device.
* `ip link set eth0 master br0` attaches the host access interface to the bridge.
* `ip link set vxlan10 master br0` connects the VXLAN tunnel to the same bridge.

### Result
Leaf 4 is prepared to send and receive VXLAN-encapsulated traffic on VNI 10 and integrate the local host segment into the EVPN fabric.

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

### Purpose
Configure the Route Reflector as a BGP EVPN route reflector, enabling it to accept EVPN sessions from leaves and reflect EVPN routes among them.

### Command Breakdown
* `router bgp 65000` enters BGP configuration for AS 65000.
* `bgp router-id 1.1.1.1` sets the BGP router ID to the Route Reflector loopback.
* `neighbor <IP> remote-as 65000` defines internal BGP peers with each leaf.
* `neighbor <IP> update-source lo` uses the loopback interface as the source for the BGP session.
* `address-family l2vpn evpn` enters EVPN address-family configuration.
* `neighbor <IP> activate` activates EVPN for each neighbor.
* `neighbor <IP> route-reflector-client` marks each leaf as a route reflector client.
* `exit-address-family` exits EVPN configuration mode.

### Result
The Route Reflector forms internal EVPN BGP sessions with each leaf and is configured to reflect EVPN routes, avoiding a full mesh of leaf-to-leaf BGP sessions.

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

### Purpose
Configure Leaf 2 as a BGP EVPN speaker and establish a session to the Route Reflector so it can advertise VXLAN endpoint reachability.

### Command Breakdown
* `router bgp 65000` enters BGP configuration for AS 65000.
* `bgp router-id 1.1.1.2` sets Leaf 2’s BGP identifier to its loopback address.
* `neighbor 1.1.1.1 remote-as 65000` defines the Route Reflector as an internal BGP peer.
* `neighbor 1.1.1.1 update-source lo` uses the loopback as the BGP source address.
* `address-family l2vpn evpn` enters EVPN configuration mode.
* `neighbor 1.1.1.1 activate` enables EVPN on the neighbor session.
* `advertise-all-vni` instructs the leaf to advertise all configured VNIs into EVPN.

### Result
Leaf 2 establishes an EVPN BGP session to the Route Reflector and begins advertising its VNI reachability information into the EVPN control plane.

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

### Purpose
Configure Leaf 3 to form a BGP EVPN session with the Route Reflector and advertise its VNI presence.

### Command Breakdown
* `bgp router-id 1.1.1.3` sets the BGP identifier to Leaf 3’s loopback.
* `neighbor 1.1.1.1 remote-as 65000` configures the Route Reflector as an IBGP neighbor.
* `neighbor 1.1.1.1 update-source lo` uses the loopback address as the source of BGP packets.
* `address-family l2vpn evpn` enables EVPN address-family configuration.
* `neighbor 1.1.1.1 activate` activates EVPN on the neighbor relationship.
* `advertise-all-vni` advertises all VNI reachability learned or configured on the leaf.

### Result
Leaf 3 joins the EVPN control plane through the Route Reflector and is ready to exchange EVPN reachability information.

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

### Purpose
Configure Leaf 4 to form an EVPN BGP session with the Route Reflector and advertise its overlay reachability.

### Command Breakdown
* `bgp router-id 1.1.1.4` sets Leaf 4’s BGP identifier.
* `neighbor 1.1.1.1 remote-as 65000` defines the Route Reflector as the IBGP peer.
* `neighbor 1.1.1.1 update-source lo` uses the loopback address for BGP session source.
* `address-family l2vpn evpn` enters EVPN configuration.
* `neighbor 1.1.1.1 activate` activates the EVPN address-family for the neighbor.
* `advertise-all-vni` causes the leaf to advertise all configured VNIs.

### Result
Leaf 4 becomes a full EVPN participant and advertises its overlay VTEP reachability to the Route Reflector.

---

# 7 - BGP Verification

Check EVPN neighbors:

```bash
vtysh
show bgp l2vpn evpn summary
```

### Purpose
Open the FRR shell and verify that the EVPN BGP sessions are established and the Route Reflector sees all leaf peers.

### Command Breakdown
* `vtysh` opens the FRR command shell.
* `show bgp l2vpn evpn summary` displays a summary of EVPN BGP neighbor status and prefix counts.

### Result
This command confirms that the Route Reflector has formed EVPN sessions with all configured leaves and that the expected peers are up.

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

### Purpose
Inspect the EVPN routing table to verify that the Route Reflector has learned the leaf VTEP routes before hosts are active.

### Command Breakdown
* `show bgp l2vpn evpn` displays all EVPN NLRI received and installed in the BGP table.

### Result
The output shows that the Route Reflector has learned the Type-3 Ethernet A-D routes for each leaf VTEP, confirming EVPN route exchange.

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

### Purpose
Enable Host 1’s access interface so the host becomes reachable on the VXLAN bridge and can participate in the overlay.

### Command Breakdown
* `ip link set eth1 up` brings the host-facing interface online.

### Result
Host 1’s interface is activated and the leaf can forward traffic for that host segment into the VXLAN EVPN fabric.

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
