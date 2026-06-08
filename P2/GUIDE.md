# 1 - Interface Preparation
Before we build the tunnel, we must ensure the "Underlay" (the connection between the routers) is working.
### On router 1
```bash
# Assuming eth1 is connected to the Switch
ip addr add 10.1.1.1/24 dev eth1
ip link set eth1 up
```

### Purpose
Assign the underlay address to Router 1’s switch-facing interface and bring that interface online for router-to-router connectivity.

### Command Breakdown
* `ip addr add` adds an IP address to an interface.
* `10.1.1.1/24` sets Router 1’s underlay IP and subnet.
* `dev eth1` specifies the switch-connected interface.
* `ip link set eth1 up` activates the interface.

### Result
Router 1 can participate in the underlay network and begin sending packets to Router 2 over the shared switch.


### On router 2
```bash
# Assuming eth1 is connected to the Switch
ip addr add 10.1.1.2/24 dev eth1
ip link set eth1 up
```

### Purpose
Assign the underlay address to Router 2’s switch-facing interface and enable the link toward Router 1.

### Command Breakdown
* `10.1.1.2/24` configures the second router’s underlay IP address.
* `ip link set eth1 up` brings the router-facing physical interface online.

### Result
Router 2 is now on the same underlay subnet as Router 1 and can exchange IP packets with it.

### Verification
From router 1 we ping router 2 to verify routers connection
```bash
ping 10.1.1.2
```

### Purpose
Test Layer 3 reachability across the underlay between the two routers.

### Command Breakdown
* `ping 10.1.1.2` sends ICMP echo requests to Router 2.

### Result
A successful ping confirms that the underlay link is working before the VXLAN overlay is built.



# 2 - Creating the bridge and VXLAN
Now we create the "Magic." We need to take the physical interface facing the Host and bridge it into a VXLAN tunnel that goes to the other router.

For the VXLAN interface, use one mode only. Do not run both `ip link add vxlan10` commands because they create the same VXLAN device.
* Static mode uses `remote` when you know the other router IP.
* Dynamic multicast mode uses `group` so routers using the same multicast group can discover each other through multicast traffic.

Both routers must use the same VNI, multicast group if multicast mode is used, and destination port. For dynamic multicast mode, the underlay must also allow multicast traffic to `239.1.1.1`.

### On router 1
```bash
# 1. Create a bridge (this acts like a virtual switch inside your router)
ip link add br0 type bridge
ip link set br0 up

# 2. Create the VXLAN interface
# Choose ONE mode:
# Do not run both commands below.
# Static mode (point-to-point)
ip link add vxlan10 type vxlan id 10 dev eth1 remote 10.1.1.2 local 10.1.1.1 dstport 4789

# Dynamic multicast mode (multicast discovery)
ip link add vxlan10 type vxlan id 10 dev eth1 group 239.1.1.1 local 10.1.1.1 dstport 4789
ip link set vxlan10 up

# 3. Connect the Host-facing interface (e.g., eth2) and the VXLAN to the bridge
ip link set eth2 master br0
ip link set vxlan10 master br0
```

### Purpose
Create the VXLAN overlay on Router 1 by building a bridge and a VNI 10 tunnel, then attach the host-facing interface. In static mode, the tunnel points directly to Router 2. In dynamic multicast mode, Router 1 sends VXLAN traffic to the multicast group instead of a fixed remote IP.

### Command Breakdown
* `ip link add br0 type bridge` creates a Linux bridge named `br0`.
* `ip link set br0 up` activates the bridge.
* `ip link add vxlan10 type vxlan` creates the VXLAN tunnel device.
* `id 10` selects VXLAN Network Identifier 10.
* `dev eth1` uses the underlay interface for VXLAN encapsulation.
* `remote 10.1.1.2` sets Router 2 as the VXLAN peer in static mode.
* `group 239.1.1.1` sets the multicast group used by dynamic multicast mode.
* `local 10.1.1.1` configures Router 1’s local source IP for the tunnel.
* `dstport 4789` uses the standard VXLAN UDP port.
* `ip link set vxlan10 up` brings the VXLAN tunnel online.
* `ip link set eth2 master br0` attaches the host-facing port to the bridge.
* `ip link set vxlan10 master br0` attaches the VXLAN tunnel to the bridge.

### Result
Router 1 is now capable of forwarding local host traffic into the VXLAN overlay, either directly toward Router 2 in static mode or through the multicast group in dynamic multicast mode.

### On router 2
```bash
# 1. Create the bridge
ip link add br0 type bridge
ip link set br0 up

# 2. Create the VXLAN interface (pointing back to Router 1)
# Choose ONE mode:
# Do not run both commands below.
# Static mode (point-to-point)
ip link add vxlan10 type vxlan id 10 dev eth1 remote 10.1.1.1 local 10.1.1.2 dstport 4789

# Dynamic multicast mode (multicast discovery)
ip link add vxlan10 type vxlan id 10 dev eth1 group 239.1.1.1 local 10.1.1.2 dstport 4789
ip link set vxlan10 up

# 3. Connect the Host-facing interface (e.g., eth2) and the VXLAN to the bridge
ip link set eth2 master br0
ip link set vxlan10 master br0
```

### Purpose
Create the VXLAN overlay on Router 2 by building the bridge and tunnel, then attach its local host-facing port. In static mode, Router 2 points back to Router 1. In dynamic multicast mode, Router 2 joins the same multicast group as Router 1.

### Command Breakdown
* `ip link add br0 type bridge` creates the bridge device.
* `ip link set br0 up` activates the bridge.
* `ip link add vxlan10 type vxlan` creates the VXLAN device for Router 2.
* `id 10` sets the overlay VNI to 10.
* `dev eth1` uses the underlay interface for VXLAN traffic.
* `remote 10.1.1.1` points the tunnel at Router 1 in static mode.
* `group 239.1.1.1` joins the same multicast group used by Router 1 in dynamic multicast mode.
* `local 10.1.1.2` sets Router 2’s source IP for the VXLAN source address.
* `dstport 4789` configures standard VXLAN UDP encapsulation.
* `ip link set vxlan10 up` brings the VXLAN tunnel online.
* `ip link set eth2 master br0` attaches the host-facing interface to the bridge.
* `ip link set vxlan10 master br0` attaches the VXLAN tunnel to the bridge.

### Result
Router 2 is prepared to forward traffic between its local host segment and the VXLAN overlay, either directly toward Router 1 in static mode or through the shared multicast group in dynamic multicast mode.

# 3 - Host IP Assignment
Finally, give your hosts IP addresses in the same subnet. They don't know the routers or the VXLAN exist; they think they are on a simple LAN.

### On host 1
```bash
ip addr add 30.1.1.1/24 dev eth1
```

### Purpose
Assign Host 1 an IP address on the shared host subnet so it can communicate over the VXLAN overlay as if on a LAN.

### Command Breakdown
* `ip addr add` adds the IP address to the host interface.
* `30.1.1.1/24` configures Host 1’s IP and subnet.
* `dev eth1` specifies the host-facing NIC.

### Result
Host 1 is now on the same subnet as Host 2 and can send traffic through its router into the VXLAN fabric.


### On host 2
```bash
ip addr add 30.1.1.2/24 dev eth1
```

### Purpose
Assign Host 2 an IP address on the same subnet as Host 1, allowing end-to-end host communication.

### Command Breakdown
* `30.1.1.2/24` configures Host 2’s address within the shared /24 network.
* `dev eth1` selects the host interface.

### Result
Host 2 is reachable from Host 1 over the VXLAN overlay once the tunnel is operational.


# 4 - The Evaluation Proof (Wireshark)
To pass the peer evaluation, you must show that the traffic is encapsulated.

Right-click the link between Router 1 and the Switch.

Select Start Capture.

From Host 1, run 
```bash
ping 30.1.1.2
```

In Wireshark, look for UDP packets. When you open one, you should see the ICMP (Ping) packet hidden inside the VXLAN header.
