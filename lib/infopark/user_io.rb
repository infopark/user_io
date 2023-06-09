# frozen_string_literal: true

module Infopark
# TODO extract into infopark base gem
class ImplementationError < StandardError; end

# TODO
# - beep (\a) on #acknowledge, #ask or #confirm (and maybe on #listen, too)
class UserIO
  class Aborted < RuntimeError
  end

  class MissingEnv < RuntimeError
  end

  class Progress
    def initialize(label, user_io)
      @label = label
      @user_io = user_io
      @spinner = "-\\|/"
    end

    def start
      unless @started
        user_io.tell("#{label} ", newline: false)
        @started = true
        reset_spinner
      end
    end

    def increment
      raise(ImplementationError, "progress not started yet") unless @started
      user_io.tell(".", newline: false)
      reset_spinner
    end

    def finish
      if @started
        user_io.tell("… ", newline: false)
        user_io.tell("OK", color: :green, bright: true)
        @started = false
      end
    end

    def spin
      raise(ImplementationError, "progress not started yet") unless @started
      user_io.tell("#{@spinner[@spin_pos % @spinner.size]}\b", newline: false)
      @spin_pos += 1
    end

    private

    attr_reader :label, :user_io

    def reset_spinner
      @spin_pos = 0
    end
  end

  class << self
    attr_accessor :global
  end

  def initialize(output_prefix: nil)
    case output_prefix
    when String
      @output_prefix = "[#{output_prefix}] "
    when Proc, Method
      @output_prefix_proc = ->() { "[#{output_prefix.call}] " }
    when :timestamp
      @output_prefix_proc = ->() { "[#{Time.now.strftime("%T.%L")}] " }
    end
    @line_pending = {}
  end

  def tell(*texts, newline: true, **line_options)
    lines = texts.flatten.map {|text| text.to_s.split("\n", -1) }.flatten

    lines[0...-1].each {|line| tell_line(line, **line_options) }
    tell_line(lines.last, newline: newline, **line_options)
  end

  def tell_pty_stream(stream, **color_options)
    color_prefix, color_postfix = compute_color(**color_options)
    write_raw(output_prefix) unless line_pending?
    write_raw(color_prefix)
    nl_pending = false
    uncolored_prefix = "#{color_postfix}#{output_prefix}#{color_prefix}"
    until stream.eof?
      chunk = stream.read_nonblock(100)
      next if chunk.empty?
      write_raw("\n#{uncolored_prefix}") if nl_pending
      chunk.chop! if nl_pending = chunk.end_with?("\n")
      chunk.gsub!(/([\r\n])/, "\\1#{uncolored_prefix}")
      write_raw(chunk)
    end
    write_raw("\n") if nl_pending
    write_raw(color_postfix)
    line_pending!(false)
  end

  def warn(*text)
    tell(*text, color: :yellow, bright: true)
  end

  def tell_error(e, **options)
    tell(e, **options, color: :red, bright: true)
    tell(e.backtrace, **options, color: :red) if Exception === e
  end

  def acknowledge(*text)
    tell("-" * 80)
    tell(*text, color: :cyan, bright: true)
    tell("-" * 80)
    tell("Please press ENTER to continue.")
    read_line
  end

  def ask(*text, default: nil, expected: "yes")
    # TODO implementation error if default not boolean or nil
    # TODO implementation error if expected not "yes" or "no"
    tell("-" * 80)
    tell(*text, color: :cyan, bright: true)
    tell("-" * 80)
    default_answer = default ? "yes" : "no" unless default.nil?
    tell("(yes/no) #{default_answer && "[#{default_answer}] "}> ", newline: false)
    until %w(yes no).include?(answer = read_line.strip.downcase)
      if answer.empty?
        answer = default_answer
        break
      end
      tell("I couldn't understand “#{answer}”.", newline: false, color: :red, bright: true)
      tell(" > ", newline: false)
    end
    answer == expected
  end

  def listen(prompt = nil, **options)
    prompt << " " if prompt
    tell("#{prompt}> ", **options, newline: false)
    read_line.strip
  end

  def confirm(*text)
    ask(*text) or raise(Aborted)
  end

  def new_progress(label)
    Progress.new(label, self)
  end

  def start_progress(label)
    new_progress(label).tap(&:start)
  end

  def background_other_threads
    unless @foreground_thread
      @background_data = []
      @foreground_thread = Thread.current
    end
  end

  def foreground
    if @foreground_thread
      @background_data.each(&STDOUT.method(:write))
      @foreground_thread = nil
      # take over line_pending from background
      @line_pending[false] = @line_pending[true]
      @line_pending[true] = false
    end
  end

  def <<(msg)
    tell(msg.chomp, newline: msg.end_with?("\n"))
  end

  def tty?
    STDOUT.tty?
  end

  def edit_file(kind_of_data, filename = nil, template: nil)
    wait_for_foreground if background?

    editor = ENV["EDITOR"] or raise(MissingEnv, "No EDITOR specified.")

    filename ||= Tempfile.new("").path
    if template && (!File.exists?(filename) || File.empty?(filename))
      File.write(filename, template)
    end

    tell("Start editing #{kind_of_data} using #{editor}…")
    sleep(1.7)
    system(editor, filename)

    File.read(filename)
  end

  def select(description, items, item_describer: :to_s, default: nil)
    return if items.empty?

    describer =
        case item_describer
        when Method, Proc
          item_describer
        else
          ->(item) { item.send(item_describer) }
        end

    choice = nil
    if items.size == 1
      choice = items.first
      tell("Selected #{describer.call(choice)}.", color: :yellow)
      return choice
    end

    items = items.sort_by(&describer)

    tell("-" * 80)
    tell("Please select #{description}:", color: :cyan, bright: true)
    items.each_with_index do |item, i|
      tell("#{i + 1}: #{describer.call(item)}", color: :cyan, bright: true)
    end
    tell("-" * 80)
    default_index = items.index(default)
    default_selection = "[#{default_index + 1}] " if default_index
    until choice
      tell("Your choice #{default_selection}> ", newline: false)
      answer = read_line.strip
      if answer.empty?
        choice = default
      else
        int_answer = answer.to_i
        if int_answer.to_s != answer
          tell("Please enter a valid integer.")
        elsif int_answer < 1 || int_answer > items.size
          tell("Please enter a number from 1 through #{items.size}.")
        else
          choice = items[int_answer - 1]
        end
      end
    end
    choice
  end

  private

  def background?
    !!@foreground_thread && @foreground_thread != Thread.current
  end

  def wait_for_foreground
    sleep(0.1) while background?
  end

  def output_prefix
    @output_prefix || @output_prefix_proc && @output_prefix_proc.call
  end

  def read_line
    wait_for_foreground if background?
    @line_pending[false] = false
    STDIN.gets.chomp
  end

  def tell_line(line, newline: true, prefix: true, **color_options)
    line_prefix, line_postfix = compute_color(**color_options)
    prefix = false if line_pending?

    out_line = "#{output_prefix if prefix}#{line_prefix}#{line}#{line_postfix}#{"\n" if newline}"
    write_raw(out_line)

    line_pending!(!newline)
  end

  def write_raw(bytes)
    if background?
      @background_data << bytes
    else
      STDOUT.write(bytes)
    end
  end

  def line_pending?
    @line_pending[background?]
  end

  def line_pending!(value)
    @line_pending[background?] = value
  end

  def compute_color(**options)
    if tty?
      if prefix = text_color(**options)
        # TODO matching annihilators for options
        postfix = text_color(color: :none, bright: false)
      end
    end
    [prefix, postfix]
  end

  def control_sequence(*parameters, function)
    "\033[#{parameters.join(";")}#{function}"
  end

  # SGR: Select Graphic Rendition … far too long for a function name ;)
  def sgr_sequence(*parameters)
    control_sequence(*parameters, :m)
  end

  def text_color(color: nil, bright: nil, faint: nil, italic: nil, underline: nil)
    return if color.nil? && bright.nil?
    sequence = []
    unless bright.nil? && faint.nil?
      sequence << (bright ? 1 : (faint ? 2 : 22))
    end
    unless italic.nil?
      sequence << (italic ? 3 : 23)
    end
    unless underline.nil?
      sequence << (underline ? 4 : 24)
    end
    case color
    when :red
      sequence << 31
    when :green
      sequence << 32
    when :yellow
      sequence << 33
    when :blue
      sequence << 34
    when :purple
      sequence << 35
    when :cyan
      sequence << 36
    when :white
      sequence << 37
    when :none
      sequence << 39
    end
    sgr_sequence(*sequence)
  end
end
end

require_relative "user_io/global"
