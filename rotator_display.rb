#!/usr/bin/env ruby
require 'tk'
require 'serialport'

class RotatorDisplay
  def read_azimuth
    Tk.after @update_interval, proc {read_azimuth}
    @serial_port.print "C\r"
    response = @serial_port.gets.chomp
    if response =~ /^\+0(\d+)/
      @azimuth = $1.to_f % 360.0
    else
      puts "Could not determine azimuth from string '#{response}'"
    end
  end

  def drawing_azimuth; @azimuth + @azimuth_draw_offset; end
  def display_azimuth; (@azimuth + @azimuth_offset).to_i.to_s + "\xB0"; end
  def display_motion_needle_azimuth; (@motion_needle_azimuth + @azimuth_draw_offset + 180.0).to_i.to_s + "\xB0"; end
  # returns [r, theta]
  def cartesian_to_polar(x, y); [Math.hypot(x, y), Math.atan2(y, x)]; end
  
  def refresh_display
    Tk.after @update_interval, proc {refresh_display}
    needle_end_x = (@center_x + (@radius * Math.cos(drawing_azimuth * (Math::PI / 180.0)))).round.abs
    needle_end_y = (@center_y + (@radius * Math.sin(drawing_azimuth * (Math::PI / 180.0)))).round.abs
    if @needle
      @needle.coords = [[@center_x, @center_y], [needle_end_x, needle_end_y]].sort.flatten
    else
      @needle = TkcLine.new(@canvas, *([[@center_x, @center_y], [needle_end_x, needle_end_y]].sort)) {
        width 3
        fill 'yellow'
      }
    end
    @az_display.text = display_azimuth
  end

  def begin_motion(event); end

  def end_motion(event)
    if @motion_needle
	    @motion_needle.delete
      @motion_needle = nil
    end
    if @motion_azimuth_text
	    @motion_azimuth_text.delete
      @motion_azimuth_text = nil
    end
  end

  def update_motion_needle_azimuth(event)
    x = event.x - @center_x
    y = event.y - @center_y;
    r, theta = cartesian_to_polar(x,y)
    @motion_needle_azimuth = (((theta * (180.0/Math::PI))+450.0) % 360.0) + @azimuth_draw_offset
  end
  
  def draw_motion_needle(event)
    needle_end_x = (@center_x + (@radius * Math.cos(@motion_needle_azimuth * (Math::PI / 180.0)))).round.abs
    needle_end_y = (@center_y + (@radius * Math.sin(@motion_needle_azimuth * (Math::PI / 180.0)))).round.abs

    if @motion_needle
      @motion_needle.coords = [[@center_x, @center_y], [needle_end_x, needle_end_y]].sort.flatten
    else
      @motion_needle = TkcLine.new(@canvas, *([[@center_x, @center_y], [needle_end_x, needle_end_y]].sort)) {
        width 3
        fill 'gray'
      }
    end
  end

  def draw_motion_azimuth_text(event)
    if @motion_azimuth_text
      @motion_azimuth_text.text = display_motion_needle_azimuth
    else
      az_text_x = ((@radius*1.625) * Math.cos(@center_x * (Math::PI / 180.0))).round.abs
      az_text_y = (@radius * Math.sin(@center_y * (Math::PI / 180.0))).round.abs
      @motion_azimuth_text = TkcText.new(@canvas, az_text_x, az_text_y) {
          text '0'
          font TkFont.new("family" => 'Helvetica', "size" => 18)
          fill 'red'
        }
    end
  end

  def maybe_rotate
    Tk.after @update_interval, proc {maybe_rotate}
    if @target_azimuth != @azimuth and (@target_azimuth < ((@azimuth + 358.0) % 360.0) or @target_azimuth > ((@azimuth + 362.0) % 360.0))
      if not @command_pending
        puts "Sending command 'M%03d\\r'" % @target_azimuth.round.to_i
        @serial_port.print "M%03d\r" % @target_azimuth.round.to_i
        @command_pending = true
	@update_interval = 250 # ms
      end
      puts "target #{@target_azimuth.round.to_i} differs from actual #{@azimuth}; requested rotation to #{@target_azimuth.round.to_i}"
    else
      @command_pending = false
      @update_interval = 1000 # ms
    end
  end

  def initialize_face
    diameter = @radius * 2.0
    margin = 25
    @center_x = @center_y = (@radius + margin)
    @canvas = TkCanvas.new(@top) {
      height diameter + (margin*2)
      width diameter + (margin*2)
      pack('padx' => margin/2, 'pady' => margin/2, 'side' => 'top')
    }
    @face ||= TkcOval.new(@canvas, 1+margin, 1+margin, diameter+margin, diameter+margin) {
      outline 'black'
      fill 'darkgray'
    }
    text_offset = 15
    (0..359).each_slice(15).map(&:first).each {|heading|
      pip_width = 1
      pip_length = 2
      if heading % 45 == 0
        pip_width = 3
        pip_length = 5
      end
      x_base = Math.cos((heading+@azimuth_draw_offset) * (Math::PI / 180.0))
      y_base = Math.sin((heading+@azimuth_draw_offset) * (Math::PI / 180.0))
      pip_x1 = @center_x + ((@radius-pip_length) * x_base).round
      pip_y1 = @center_y + ((@radius-pip_length) * y_base).round
      pip_x2 = @center_x + ((@radius+pip_length) * x_base).round
      pip_y2 = @center_y + ((@radius+pip_length) * y_base).round
      text_x1 = @center_x + ((@radius-text_offset) * x_base).round
      text_y1 = @center_y + ((@radius-text_offset) * y_base).round
      text_x2 = @center_x + ((@radius+text_offset) * x_base).round
      text_y2 = @center_y + ((@radius+text_offset) * y_base).round
      TkcLine.new(@canvas, pip_x1, pip_y1, pip_x2, pip_y2) {
        width 3
        fill 'black'
      }
      if heading % 45 == 0
        TkcText.new(@canvas, text_x2, text_y2) {
          text heading.to_s
        }
      end
    }

    @canvas.bind("Button-1", proc {|event|
      x = event.x - @center_x
      y = event.y - @center_y;
      r, theta = cartesian_to_polar(x,y)
      @target_azimuth = ((theta * (180.0/Math::PI))+450.0) % 360.0
    })

    @canvas.bind("Enter", proc {|event| begin_motion(event)})
    @canvas.bind("Motion", proc {|event|
      update_motion_needle_azimuth(event)
      draw_motion_needle(event)
      draw_motion_azimuth_text(event)
    })
    @canvas.bind("Leave", proc {|event| end_motion(event)})

    @az_display = TkLabel.new(@top) {
      text '360'
      borderwidth 3
      background 'black'
      foreground 'yellow'
      font TkFont.new("family" => 'Helvetica', "size" => 36, "weight" => 'bold')
      pack('fill' => 'x', 'expand' => 1, 'side' => 'bottom')
    }
  end
  
  def initialize(options)
    @top = TkRoot.new { title 'Rotator' }
    menu_spec = [
      [
        ['File'],
        ['Exit', proc { exit }],
      ],
      [
        ['Help'],
        ['About', proc { puts "About" }],
      ],
    ]
    menu = TkMenubar.new(@top, menu_spec, 'tearoff' => false)
    menu.pack('fill' => 'x', 'side' => 'top')
    @azimuth_offset = 0.0 # degrees
    @azimuth_draw_offset = -90.0 # degrees
    @azimuth = 0.0
    @radius = 200.0
    @update_interval = 1000  # ms
    @draw_motion_needle_azimuth = false

    data_bits = 8
    stop_bits = 1
    parity = SerialPort::NONE
    puts "Before serialport"
    @serial_port = SerialPort.new(options[:serial_port], options[:baud], data_bits, stop_bits, parity)
    puts "After serialport"
    @serial_port.flow_control = SerialPort::NONE

    initialize_face
    read_azimuth
    @target_azimuth = @azimuth
    @command_pending = false
    refresh_display
    maybe_rotate
  end
end


rd = RotatorDisplay.new(:serial_port => 'COM6', :baud => 9600)
Tk.mainloop

