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

  def maybe_rotate
    Tk.after @update_interval, proc {maybe_rotate}
    if @target_azimuth != @azimuth and (@target_azimuth < ((@azimuth + 358.0) % 360.0) or @target_azimuth > ((@azimuth + 362.0) % 360.0))
      if not @command_pending
        puts "Sending command 'M%03d\\r'" % @target_azimuth.round.to_i
        @serial_port.print "M%03d\r" % @target_azimuth.round.to_i
        @command_pending = true
      end
      puts "target #{@target_azimuth.round.to_i} differs from actual #{@azimuth}; requested rotation to #{@target_azimuth.round.to_i}"
    else
      @command_pending = false
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

    @canvas.bind("Button-1",
                 proc do |event|
                   x = event.x - @center_x
                   y = event.y - @center_y
                   theta = Math.atan2(y, x)
                   r = Math.hypot(x, y)
                   @target_azimuth = ((theta * (180.0/Math::PI))+450.0) % 360.0
                 end)

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
    @update_interval = 250  # ms

    data_bits = 8
    stop_bits = 1
    parity = SerialPort::NONE
    @serial_port = SerialPort.new(options[:serial_port], options[:baud], data_bits, stop_bits, parity)
    @serial_port.flow_control = SerialPort::NONE

    initialize_face
    read_azimuth
    @target_azimuth = @azimuth
    @command_pending = false
    refresh_display
    maybe_rotate
  end
end


rd = RotatorDisplay.new(:serial_port => 'COM3', :baud => 9600)
Tk.mainloop

