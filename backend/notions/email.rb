require 'pony'

post '/email' do
  request_payload = JSON.parse(request.body.read)
  email_message = request_payload['message']
  sender_email = ENV['EMAIL_USER']        # set this in your .env.local
  sender_password = ENV['EMAIL_PASSWORD'] # same thing for this one
  recipient_email = 'notify@simone.computer'

  if sender_email.nil? || sender_password.nil? || recipient_email.nil?
    status 500
    return 'Error: Server environment variables (EMAIL_USER, EMAIL_PASSWORD, RECIPIENT_EMAIL) are not set.'
  end

  begin
    Pony.mail(
      to: recipient_email,
      from: "Max Headbox <#{sender_email}>",
      subject: 'New Message from Max Headbox',
      body: "Max Headbox says:\n\n#{email_message}",
      via: :smtp,
      via_options: {
        address: 'mail.privateemail.com',
        port: '587',
        enable_starttls_auto: true,
        user_name: sender_email,
        password: sender_password,
        authentication: :plain,
        domain: 'simone.computer'
      }
    )

    content_type :json
    { message: "Email sent successfully to #{recipient_email}!" }.to_json
  rescue StandardError => e
    status 500
    "Failed to send email. Error: #{e.message}"
  end
end
