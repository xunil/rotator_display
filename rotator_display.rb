require 'tk'

class RotatorDisplay
  def read_azimuth
    Tk.after @update_interval, proc {read_azimuth}
    @azimuth = (@azimuth + 1.0) % 360.0
  end
  
  def refresh_display
    Tk.after @update_interval, proc {refresh_display}
    needle_end_x = (@center_x + (@radius * Math.cos(@azimuth * (Math::PI / 180.0)))).round.abs
    needle_end_y = (@center_y + (@radius * Math.sin(@azimuth * (Math::PI / 180.0)))).round.abs
    if @needle
      @needle.coords = [[@center_x, @center_y], [needle_end_x, needle_end_y]].sort.flatten
    else
      @needle = TkcLine.new(@canvas, *([[@center_x, @center_y], [needle_end_x, needle_end_y]].sort)) {
        width 5
        fill 'yellow'
      }
    end
  end

  def initialize_face
    diameter = @radius * 2.0
    margin = 50
    @center_x = @center_y = (@radius + (margin / 2))
    @canvas = TkCanvas.new(@top) {
      height diameter + margin
      width diameter + margin
      pack('padx' => margin / 2,
           'pady' => margin / 2,
           'side' => 'left')
    }
    @face ||= TkcOval.new(@canvas, 1+(margin/2), 1+(margin/2), diameter+(margin/2), diameter+(margin/2)) {
      outline 'black'
      fill 'darkgray'
    }
    pip_length = 5
    text_offset = 15
    (0..359).each_slice(45).map(&:first).each {|heading|
      x_base = Math.cos((heading-@heading_offset) * (Math::PI / 180.0))
      y_base = Math.sin((heading-@heading_offset) * (Math::PI / 180.0))
      pip_x1 = @center_x + ((@radius-pip_length) * x_base).round
      pip_y1 = @center_y + ((@radius-pip_length) * y_base).round
      pip_x2 = @center_x + ((@radius+pip_length) * x_base).round
      pip_y2 = @center_y + ((@radius+pip_length) * y_base).round
      text_x1 = @center_x + ((@radius-text_offset) * x_base).round
      text_y1 = @center_y + ((@radius-text_offset) * y_base).round
      text_x2 = @center_x + ((@radius+text_offset) * x_base).round
      text_y2 = @center_y + ((@radius+text_offset) * y_base).round
      TkcLine.new(@canvas, pip_x1, pip_y1, pip_x2, pip_y2) {
        width 1
        fill 'black'
      }
      TkcText.new(@canvas, text_x2, text_y2) {
        text heading.to_s
      }
    }
  end
  
  def initialize
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
    @heading_offset = 90.0 # degrees
    @azimuth = 0.0
    @radius = 200.0
    @update_interval = 25

    initialize_face
    read_azimuth
    refresh_display
  end
end


rd = RotatorDisplay.new
Tk.mainloop

