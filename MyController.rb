# Project 2 - SDN Controller
# Author: Carlos Galdamez
#         Jose Rivas
#         Eduardo Lopez-Serrano
# Code was used from the following repository: https://github.com/trema/trema-edge.git
# Author from code that was used: Yasuhito Takamiya

require 'trema/exact-match'
require_relative 'fdb'

class MyController < Controller
  # Causes fowarding table to check every five seconds whether any entries in the
  # fowarding table have aged, if they have then they are removed
  add_timer_event :age_fdb, 5, :periodic

  def start
    @fdb = FDB.new
  end

  # Used by virtual switch, tells virtual switch how to deal with packets it receives
  # @param 'datapath_id' is extracted from the configuration file
  def switch_ready(datapath_id)
    # Creates an action to be performed on packets the switch receives.
    # Setting the 'port_number' to 'OFPP_CONTROLLER' tells the switch to send the packet to the controller.
    # Setting 'mas_len" to 'OFCPCML_NO_BUFFER' I believe tells the switch to send the whole packet to the controller
    action = SendOutPort.new(port_number: OFPP_CONTROLLER, max_len: OFPCML_NO_BUFFER) # This is an action to output a packet to a port
    ins = ApplyAction.new(actions: [action])
    # Adds a new entry to the switch fowarding table only if it does not exist in the table already
    # If it does not have an entry that tells it how to deal with this packet then it will execute the action
    # specified in 'action' which would be to send it to the controller.
    send_flow_mod_add(datapath_id,
                      priority: OFP_LOW_PRIORITY,
                      buffer_id: OFP_NO_BUFFER,
                      flags: OFPFF_SEND_FLOW_REM, # If flow entries match, and must be deleted, then each normal entry with the 'OFPFF_SEND_FLOW_REM' flag set should generate a flow removed message.
                      instructions: [ins]
    )
  end

  # Acts as the controller
  def packet_in(datapath_id, packet)
    # fdb is the fowarding database class (fowarding table for controller...there are two separte ones)
    # 'fdb.learn takes in the mac address attribute and first checks whether mac address
    # exists in the fowarding table, if it does not it creates a new entry in the fowarding 
    # table for that mac address
    @fdb.learn packet.eth_src, packet.in_port
    # 'fdb' class tries to extract port number of destination mac if it is in the
    #  fowarding table 
    port_no = @fdb.port_no_of(packet.eth_dst)
    
    # There is a possibility that port number for destination mac address was
    # not found in the fowarding table. If that is the case then we call the flood method.
    # What the flood method does is that it sends the packet to all physical ports except the input port( does a breath first search)
    # If there is a port entry for the destination in the fowarding table, a header with instructions on how to handle
    # this packet is added to the packet using the flow_mod method and then a new action is created to 
    # send the packet to the destination 
    if port_no
      flow_mod datapath_id, packet, port_no
      packet_out datapath_id, packet, port_no
    else
      flood datapath_id, packet
    end

    # First two conditions are used to filter out what we dont want to be displayed
    # Information from packets that we want will then be extracted and displayed on the console
    if packet.ipv4?
      if in_addresses packet.ipv4_src, packet.ipv4_dst
        puts 'Received a packet!'
        info "datapath_id: #{ datapath_id.to_hex }"
        info "transaction_id: #{ packet.transaction_id.to_hex }"
        info "buffer_id: #{ packet.buffer_id.to_hex }"
        info "total_len: #{ packet.total_len }"
        info "reason: #{ packet.reason.to_hex }"
        info "table_id: #{ packet.table_id }"
        info "cookie: #{ packet.cookie.to_hex }"
        info "in_port: #{ packet.match.in_port }"
        info "data: #{ packet.data.map! { | byte | '0x%02x' % byte } }"
        info 'packet_info:'
        info "  eth_src: #{ packet.eth_src }"
        info "  eth_dst: #{ packet.eth_src }"
        info "  eth_type: #{ packet.eth_type.to_hex }"

        if packet.eth_type == 0x800 || packet.eth_type == 0x86dd
          info "  ip_dscp: #{ packet.ip_dscp }"
          info "  ip_ecn: #{ packet.ip_ecn }"
          info "  ip_proto: #{ packet.ip_proto }"
        end

        if packet.vtag?
          info "  vlan_vid: #{ packet.vlan_vid.to_hex }"
          info "  vlan_prio: #{ packet.vlan_prio.to_hex }"
          info "  vlan_tpid: #{ packet.vlan_tpid.to_hex }"
          info "  vlan_tci: #{ packet.vlan_tci.to_hex }"
        end

        info "  ipv4_src: #{ packet.ipv4_src }"
        info "  ipv4_dst: #{ packet.ipv4_dst }"

        if packet.arp?
          info "  arp_op: #{ packet.arp_op }"
          info "  arp_sha: #{ packet.arp_sha }"
          info "  arp_spa: #{ packet.arp_spa }"
          info "  arp_tpa: #{ packet.arp_tpa }"
       end

        if packet.icmpv4?
          info "  icmpv4_type: #{ packet.icmpv4_type.to_hex }"
          info "  icmpv4_code: #{ packet.icmpv4_code.to_hex }"
        end

        if packet.udp?
          info "  udp_src: #{ packet.udp_src.to_hex }"
          info "  udp dst: #{ packet.udp_dst.to_hex }"
        end

        if packet.sctp?
          info "  sctp_src: #{ packet.sctp_src.to_hex }"
          info "  sctp_dst: #{ packet.sctp_dst.to_hex }"
        end

        if packet.pbb?
          info "  pbb_isid: #{ packet.pbb_isid.to_hex }"
        end

        if packet.mpls?
          info "  mpls_label: #{ packet.mpls_label.to_hex }"
          info "  mpls_tc: #{ packet.mpls_tc.to_hex }"
          info "  mpls_bos: #{ packet.mpls_bos.to_hex }"
        end
      end
    end
  end

  # Calls age method in fdb class which checks if any of the entries of the fowarding table have aged
  # if they have then they are removed.
  def age_fdb
    @fdb.age
  end

  # --------------------------- PRIVATE METHODS ----------------------------#
  private

  # Method used for filtering through all packets arriving through virtual switch
  # If more virtual hosts are addded IP address can be added to the array
  def in_addresses(source_IP,dest_IP)
     addresses = ["192.168.0.1", "192.168.0.2", "192.168.0.3"]
     return addresses.include?(dest_IP.to_s) && addresses.include?(source_IP.to_s)
  end  
  
  # Adds to switch fowarding table
  def flow_mod(datapath_id, message, port_no)
    action = SendOutPort.new(port_number: port_no)
    ins = ApplyAction.new(actions: [action])
    send_flow_mod_add(
      datapath_id,
      match: ExactMatch.from(message),
      instructions: [ins]
    )
  end

  # Sends packet to specified port
  def packet_out(datapath_id, message, port_no)
    action = SendOutPort.new(port_number: port_no)
    send_packet_out(
      datapath_id,
      packet_in: message,
      actions: [action]
    )
  end

  # Sets destination port to 'OFPP_ALL' meaning that when packet is sent
  # it will be sent to all physical ports except the input port
  def flood(datapath_id, message)
    packet_out datapath_id, message, OFPP_ALL
  end
end
