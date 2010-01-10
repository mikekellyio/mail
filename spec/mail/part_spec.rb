require File.join(File.dirname(File.expand_path(__FILE__)), '..', 'spec_helper')

describe Mail::Part do
        
  it "should put content-ids into parts" do
    part = Mail::Part.new do
      body "This is Text"
    end
    part.to_s
    part.content_id.should_not be_nil
  end
  
  it "should preserve any content id that you put into it" do
    part = Mail::Part.new do
      content_id "<thisis@acontentid>"
      body "This is Text"
    end
    part.content_id.should == "<thisis@acontentid>"
  end
  
  describe "parts that have a missing header" do
    it "should not try to init a header if there is none" do
      part =<<PARTEND

The original message was received at Mon, 24 Dec 2007 10:03:47 +1100
from 60-0-0-146.static.tttttt.com.au [60.0.0.146]

This message was generated by mail12.tttttt.com.au

   ----- The following addresses had permanent fatal errors -----
<edwin@zzzzzzz.com>
    (reason: 553 5.3.0 <edwin@zzzzzzz.com>... Unknown E-Mail Address)

   ----- Transcript of session follows -----
... while talking to mail.zzzzzz.com.:
>>> DATA
<<< 553 5.3.0 <edwin@zzzzzzz.com>... Unknown E-Mail Address
550 5.1.1 <edwin@zzzzzzz.com>... User unknown
<<< 503 5.0.0 Need RCPT (recipient)

-- 
This message has been scanned for viruses and
dangerous content by MailScanner, and is
believed to be clean.
PARTEND
      STDERR.should_not_receive(:puts)
      Mail::Part.new(part)
    end
  end
  
  describe "delivery status reports" do
    before(:each) do
      part =<<ENDPART
Content-Type: message/delivery-status

Reporting-MTA: dns; mail12.rrrr.com.au
Received-From-MTA: DNS; 60-0-0-146.static.tttttt.com.au
Arrival-Date: Mon, 24 Dec 2007 10:03:47 +1100

Final-Recipient: RFC822; edwin@zzzzzzz.com
Action: failed
Status: 5.3.0
Remote-MTA: DNS; mail.zzzzzz.com
Diagnostic-Code: SMTP; 553 5.3.0 <edwin@zzzzzzz.com>... Unknown E-Mail Address
Last-Attempt-Date: Mon, 24 Dec 2007 10:03:53 +1100
ENDPART
      @delivery_report = Mail::Part.new(part)
    end

    it "should know if it is a delivery-status report" do
      @delivery_report.should be_delivery_status_report_part
    end
    
    it "should create a delivery_status_data header object" do
      @delivery_report.delivery_status_data.should_not be_nil
    end

    it "should be bounced" do
      @delivery_report.should be_bounced
    end
    
    it "should say action 'delayed'" do
      @delivery_report.action.should == 'failed'
    end
    
    it "should give a final recipient" do
      @delivery_report.final_recipient.should == 'RFC822; edwin@zzzzzzz.com'
    end
    
    it "should give an error code" do
      @delivery_report.error_status.should == '5.3.0'
    end
    
    it "should give a diagostic code" do
      @delivery_report.diagnostic_code.should == 'SMTP; 553 5.3.0 <edwin@zzzzzzz.com>... Unknown E-Mail Address'
    end
    
    it "should give a remote-mta" do
      @delivery_report.remote_mta.should == 'DNS; mail.zzzzzz.com'
    end
    
    it "should be retryable" do
      @delivery_report.should_not be_retryable
    end


  end

  describe "adding a file" do
    it "should read a file name if given one" do
      filename = fixture('attachments', 'test.png')
      doing { Mail::Part.new(:filename => filename) }.should_not raise_error
    end

    it "should set it's content type intelligently for png files" do
      filename = fixture('attachments', 'test.png')
      part = Mail::Part.new(:filename => filename)
      part.content_type.should == 'image/png; filename="test.png"'
    end
    
    it "should know it is an attachment" do
      filename = fixture('attachments', 'test.png')
      part = Mail::Part.new(:filename => filename)
      part.should be_attachment
    end

    it "should be able to detatch a file" do
      filename = fixture('attachments', 'test.png')
      part = Mail::Part.new(:filename => filename)
      if RUBY_VERSION >= '1.9'
        tripped = part.attachment.decoded.force_encoding(Encoding::BINARY)
        original = File.read(filename).force_encoding(Encoding::BINARY)
        tripped.should == original
      else
        part.attachment.decoded.should == File.read(filename)
      end
    end

    it "should set it's encoding to base64 if given an attachment" do
      filename = fixture('attachments', 'test.png')
      part = Mail::Part.new(:filename => filename)
      part.ready_to_send!
      part.content_transfer_encoding.should == 'base64'
    end

    it "should round trip an image attachment" do
      filename = fixture('attachments', 'test.png')
      part = Mail::Part.new(:filename => filename)
      part.ready_to_send!
      new_part = Mail::Part.new(part.encoded)
      if RUBY_VERSION >= '1.9'
        tripped = part.attachment.decoded.force_encoding(Encoding::BINARY)
        original = File.read(filename).force_encoding(Encoding::BINARY)
        tripped.should == original
      else
        part.attachment.decoded.should == File.read(filename)
      end
    end

  end

end
