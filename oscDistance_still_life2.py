"""
oscDistance_still_life.py
john eagle
sends sensor readings without being pinged every .25 seconds
"""

# standard imports
import socket, argparse, random, time
from datetime import datetime, timedelta

# pi import
import RPi.GPIO as GPIO

# osc imports
from pythonosc import dispatcher, osc_server, osc_message_builder, udp_client

# globals
TRIG = 23
ECHO = 24

def ultrasonic_init():
    # initialize ultrasonic
    GPIO.setmode(GPIO.BCM)

    GPIO.setup(TRIG, GPIO.OUT)
    GPIO.setup(ECHO, GPIO.IN)

    GPIO.output(TRIG, False)
    time.sleep(2)

def get_reading():
    # does a ping or something
    GPIO.output(TRIG, True)
    time.sleep(0.00001)
    GPIO.output(TRIG, False)

    break_loop = False
    timeout = datetime.now() + timedelta(seconds=1)

    pulse_end = 0
    pulse_start = 0

    # finds the time measurements?
    while GPIO.input(ECHO)==0:
        pulse_start = time.time()
        # if timeout > datetime.now():
        #    break;

    timeout = datetime.now() + timedelta(seconds=1)
    while GPIO.input(ECHO)==1:
        pulse_end = time.time()
        # if timeout > datetime.now():
        #     break;

    # some calculations to convert to centimeters
    pulse_duration = pulse_end - pulse_start
    distance = pulse_duration * 17150
    return round(distance, 2)

def send_reading(reading):
    packet = osc_message_builder.OscMessageBuilder(address="/distance")

    # adds distance reading to the OSC message
    packet.add_arg(reading, arg_type='f')

    # completes the OSC message
    packet = packet.build()

    # sends distance back to host
    client.send(packet)
    #print("sending", "/distance", reading)

# MAIN PROGRAM
if __name__ == "__main__":
    # OSC variables
    piPort = 10001
    localIP = "127.0.0.1"

    ultrasonic_init()

    # set up arguments for the dispatcher
    parser = argparse.ArgumentParser()
    parser.add_argument("--hostIp", type=str, default=localIP,
                        help="The IP address to send back to`")
    parser.add_argument("--hostPort", type=int, default=piPort,
                        help="The port to send back to")
    args = parser.parse_args()

    client = udp_client.UDPClient(args.hostIp, args.hostPort)

    last_reading = 0.0

    # loop which gets and sends reading
    while True:
        reading = get_reading()
        #print(reading)
        if reading > 0:
            # to smooth out readings
            averaged = reading + last_reading / 2
            send_reading(averaged)
            #print(reading)
            # set last_reading to this one
            last_reading = reading

        time.sleep(.25) # changed from 0.1
        # sleep
