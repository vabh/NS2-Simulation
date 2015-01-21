#Create a simulator object
set ns [new Simulator]

set namfile [open hw.nam w]
$ns namtrace-all $namfile

#simulation time
set simTime 10.0
set bufferSize 16
set windSize 50

#open files for output
set f0 [open RTTvsTime.tr w]
set f1 [open WINDvsTime.tr w]
set f2 [open DRATEvsTime.tr w]
set f3 [open QDELAYvsTime.tr w]
set f4 [open DRATEvsP.tr w]

proc finish {} {
	global ns nf f0 f1 f2 f3 f4
	$ns flush-trace
	#close open files
	close $f0
	close $f1
	close $f2
	close $f3
	close $f4
	#Plot the graphs
	exec xgraph RTTvsTime.tr -geometry 850x400 &
	exec xgraph WINDvsTime.tr -geometry 850x400 &
	exec xgraph DRATEvsTime.tr -geometry 850x400 &
	exec xgraph QDELAYvsTime.tr -geometry 850x400 &
	exec xgraph DRATEvsP.tr -geometry 850x400 &

	exit 0
}

set nClient [$ns node]
set nServer [$ns node]

#Create links between the nodes
$ns duplex-link $nServer $nClient 10Mb 20ms DropTail

$ns queue-limit $nServer $nClient $bufferSize
set qmon [$ns monitor-queue $nServer $nClient 0.1]

proc grapher {} {
	global sink f0 f1 f2 tcp
	set ns [Simulator instance]
	#Set the time after which the procedure should be called again
	set time 0.1
	
	#Get the current time and values of RTT, CWND
	set now [$ns now]
	set rtt [$tcp set rtt_]
	set congW [$tcp set cwnd_]

	puts $f0 "$now $rtt"

	puts $f1 "$now $congW"

	set v [expr $congW * [expr [$tcp set packetSize_] / 1000000.0]]
	
	if {[$tcp set rtt_] != 0} {
		puts $f2 "$now [expr $v/[expr $rtt * 0.001]]"
	}
	
	$ns at [expr $now+$time] "grapher"
}

proc queueLength {sum  number outfile} {
	
	global ns qmon tcp

	set congW [$tcp set cwnd_]

	set time 0.1
	set len [$qmon set pkts_]
	set now [$ns now]
	set sum [expr $sum+$len]
	set number [expr $number+1]
	set delay [expr 1.0*$sum/$number]
	puts  $outfile  "$now $delay"
	$ns at [expr $now+$time] "queueLength $sum $number $outfile"
}

proc drate_p {p} {
	
	global ns tcp f4

	set rtt [$tcp set rtt_]

	set time 0.1

	puts $f4 "$now $delay"

	set p1 [expr $p+0.1]
	if {[$p1] != 1.0} {
		"drate_p $p1"
	}
}

#Setup a TCP connection
set tcp [new Agent/TCP/Newreno]
$ns attach-agent $nServer $tcp
$tcp set tcpTick_ 0.001

set sink [new Agent/TCPSink]
$ns attach-agent $nClient $sink
$ns connect $tcp $sink
#window size
$tcp set window_ $windSize
#$tcp set maxcwnd_ $windSize
$tcp set packetSize_ 1500
#set slowstart threshold
$ns at 0.0 "$tcp set ssthresh_ 16"
#Setup a FTP over TCP connection
set ftp [new Application/FTP]
$ftp attach-agent $tcp
#Schedule events for FTP agent


# set u [new RandomVariable/Uniform]
# $u set min_ 0
# $u set max_ 1

# set rng [new RNG]
# $rng seed 10
# set u [new RandomVariable/Uniform]
# $u set avg 50
# $u use-rng $rng

set n [new RandomVariable/Normal]
$n set max_ 0.0
$n set min_ 1.0

set lossModel [new ErrorModel]
$lossModel set rate_ 0.01
$lossModel unit packet
$lossModel drop-target [new Agent/Null]
set lossyLink [$ns link $nServer $nClient]
$lossyLink install-error $lossModel

$ns at 0.0 "grapher"
$ns at 0 "queueLength 0 0 $f3"
$ns at 0.1 "$ftp start"
$ns at $simTime "$ftp stop"

$ns at $simTime "finish"
$ns run