#!/usr/bin/env ruby
# frozen_string_literal: true

require 'openssl'
require 'socket'
require 'time'
require 'timeout'

class SslClient
  DEFAULT_SSL_VERIFY_MODE = OpenSSL::SSL::VERIFY_PEER
  DEFAULT_SNI = true
  DEFAULT_TIMEOUT = 5
  DEFAULT_SSL_MAX_VERSION = OpenSSL::SSL::TLS1_2_VERSION
  DEFAULT_PORT = 443

  attr_reader :ca_path, :ca_file, :sni, :ssl_verify_mode, :client_cert,
              :client_key, :timeout

  # rubocop:disable Metrics/ParameterLists
  def initialize(ca_path: nil,
                 ca_file: nil,
                 sni: DEFAULT_SNI,
                 ssl_verify_mode: DEFAULT_SSL_VERIFY_MODE,
                 client_cert: nil,
                 client_key: nil,
                 timeout: DEFAULT_TIMEOUT)
    @ca_path = ca_path
    @ca_file = ca_file
    @sni = sni
    @ssl_verify_mode = ssl_verify_mode
    @client_cert = client_cert
    @client_key = client_key
    @timeout = timeout
  end
  # rubocop:enable Metrics/ParameterLists

  def get_ssl_info(host:, port: nil)
    port ||= DEFAULT_PORT
    info = SslInfo.new(host: host, port: port)
    begin
      Timeout.timeout(timeout) do
        tcp_socket = TCPSocket.open(host, port)
        ssl_socket = OpenSSL::SSL::SSLSocket.new(tcp_socket, ssl_context)
        ssl_socket.hostname = host if sni
        ssl_socket.connect
        ssl_socket.sysclose
        tcp_socket.close
        # cert_store.verify(ssl_socket.peer_cert, ssl_socket.peer_cert_chain)
        info.cert = ssl_socket.peer_cert
        info.cert_chain = ssl_socket.peer_cert_chain
        info.ssl_version = ssl_socket.ssl_version
      end
    rescue StandardError => e
      info.error = e
    end
    info
  end

  def ssl_store
    OpenSSL::X509::Store.new.tap do |store|
      store.set_default_paths
      store.add_path(ca_path) if ca_path
      store.add_file(ca_file) if ca_file
    end
  end

  def ssl_context
    OpenSSL::SSL::SSLContext.new.tap do |ssl_context|
      ssl_context.verify_mode = ssl_verify_mode
      ssl_context.cert_store = ssl_store
      ssl_context.min_version = nil
      ssl_context.max_version = DEFAULT_SSL_MAX_VERSION
      if client_cert
        ssl_context.cert = OpenSSL::X509::Certificate.new(File.open(client_cert))
      end
      if client_key
        ssl_context.key = OpenSSL::PKey::RSA.new(File.open(client_key))
      end
    end
  end
end

class SslInfo
  OK = 1
  KO = 0
  attr_reader :time
  attr_accessor :host, :port, :cert, :cert_chain, :ssl_version, :error

  # rubocop:disable Metrics/ParameterLists
  def initialize(host: nil, port: nil, cert: nil, cert_chain: nil,
                 ssl_version: nil, error: nil, time: Time.now)
    @host = host
    @port = port
    @cert = cert
    @cert_chain = cert_chain
    @ssl_version = ssl_version
    @error = error
    @time = time
  end

  # rubocop:enable Metrics/ParameterLists
  def subject_s
    cert.subject.to_s if cert&.subject
  end

  def expire_in_days
    return unless cert&.not_after

    expire_in = cert.not_after
    ((expire_in - time) / 3600 / 24).to_i
  end

  def not_after
    return unless cert

    cert.not_after.iso8601(3)
  end

  def serial
    cert&.serial&.to_s(16)&.downcase
  end

  def status
    return KO if error

    OK
  end

  def error_class
    return unless error

    error.class.to_s
  end

  def to_h
    {
      host: host,
      port: port,
      subject: subject_s,
      remaining_days: expire_in_days,
      not_after: not_after,
      serial: serial,
      status: status,
      error: error
    }
  end
end

def display_data_h(data_h)
  col1_width = data_h.keys.map(&:to_s).map(&:length).max + 2
  data_h.each do |key, value|
    puts key.to_s.ljust(col1_width) + value.to_s
  end
end

######################################### main
host = ARGV[0]
port = ARGV[1]

raise 'please specify at least a host !' if !host || host.empty?

ssl_client = SslClient.new
ssl_info = ssl_client.get_ssl_info(host: host, port: port)

display_data_h(ssl_info.to_h)
