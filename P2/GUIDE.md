# 1 - Interface Preparation
Before we build the tunnel, we must ensure the "Underlay" (the connection between the routers) is working.
### On router 1
```bash
# Assuming eth1 is connected to the Switch
ip addr add 10.1.1.1/24 dev eth1
ip link set eth1 up
```



### On router 2
```bash
# Assuming eth1 is connected to the Switch
ip addr add 10.1.1.2/24 dev eth1
ip link set eth1 up
```

### Verification
From router 1 we ping router 2 to verify routers connection
```bash
ping 10.1.1.2
```



# 2 - Creating the bridge and VXLAN
Now we create the "Magic." We need to take the physical interface facing the Host and bridge it into a VXLAN tunnel that goes to the other router.
### On router 1
```bash
# 1. Create a bridge (this acts like a virtual switch inside your router)
ip link add br0 type bridge
ip link set br0 up

# 2. Create the VXLAN interface
# id 10: The Virtual Network Identifier (VNI)
# remote 10.1.1.2: The destination (Router 2)
# local 10.1.1.1: The source (Router 1)
# dstport 4789: The standard port for VXLAN
ip link add vxlan10 type vxlan id 10 dev eth1 remote 10.1.1.2 local 10.1.1.1 dstport 4789
ip link set vxlan10 up

# 3. Connect the Host-facing interface (e.g., eth2) and the VXLAN to the bridge
ip link set eth2 master br0
ip link set vxlan10 master br0
```

### On router 2
```bash
# 1. Create the bridge
ip link add br0 type bridge
ip link set br0 up

# 2. Create the VXLAN interface (pointing back to Router 1)
ip link add vxlan10 type vxlan id 10 dev eth1 remote 10.1.1.1 local 10.1.1.2 dstport 4789
ip link set vxlan10 up

# 3. Connect the Host-facing interface (e.g., eth2) and the VXLAN to the bridge
ip link set eth2 master br0
ip link set vxlan10 master br0
```

# 3 - Host IP Assignment
Finally, give your hosts IP addresses in the same subnet. They don't know the routers or the VXLAN exist; they think they are on a simple LAN.

### On host 1
```bash
ip addr add 30.1.1.1/24 dev eth1
```


### On host 2
```bash
ip addr add 30.1.1.2/24 dev eth1
```


# 4 - The Evaluation Proof (Wireshark)
To pass the peer evaluation, you must show that the traffic is encapsulated.

Right-click the link between Router 1 and the Switch.

Select Start Capture.

From Host 1, run 
```bash
ping 30.1.1.2
```

In Wireshark, look for UDP packets. When you open one, you should see the ICMP (Ping) packet hidden inside the VXLAN header.