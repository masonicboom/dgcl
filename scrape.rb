require 'open-uri'
require 'nokogiri'
require 'uri'


$last_download_at = nil
MIN_DELAY_SECS = 2.0
def download(url, filename)
  # cache
  return File.open(filename) { |f| f.read } if File.exists? filename
  
  # rate limit
  unless $last_download_at.nil?
    until Time.now - $last_download_at > MIN_DELAY_SECS do
      # wait...
    end
  end
  
  # download
  $last_download_at = Time.now
  p "#{$last_download_at}: downloading #{url}"
  contents = open(url) { |f| f.read }
  
  # save
  File.open(filename, 'w') { |f| f << contents }
  
  # return
  contents
end


# Note: this function is hardcoded, but could be generalized to scrape all titles from http://delcode.delaware.gov/
def titles
  [ { :number => 8, :title => 'Corporations', :ref_url => 'http://delcode.delaware.gov/title8/index.shtml' } ]
end

# Note: this function is hardcoded for DGCL, but could be generalized to scrape all chapters from the given title
def chapters(title)
  return nil unless title[:number] == 8
  [ { :number => 1, :title => 'GENERAL CORPORATION LAW', :ref_url => 'http://delcode.delaware.gov/title8/c001/index.shtml' } ]
end

def subchapters(chapter)
  html = download(chapter[:ref_url], "chapter#{chapter[:number]}.html")
  
  uri = URI.parse(chapter[:ref_url])
    
  doc = Nokogiri::HTML(html)
  doc.xpath('//div[@id="pagenav"]/ul//a').map do |link|
    link_text = link.content
    m = link_text.match(/Subchapter (.+)\. (.+)/)
    
    ref_path = link['href']
    ref_url = uri.merge(link['href']).to_s
    
    { :number => m[1], :title => m[2], :ref_url => ref_url }
  end
end


def sections(chapter_number, subchapter)
  html = download(subchapter[:ref_url], "subchapter#{chapter_number}.#{subchapter[:number]}.html")
  uri = URI.parse(subchapter[:ref_url])
  
  doc = Nokogiri::HTML(html)
  doc.xpath('//p[@class="section-label"]').map do |element|
    m = element.content.match(/. (.+)\. (.+)$/)
    number, title = m[1], m[2]
    url = "#{subchapter[:ref_url]}##{number}"
    
    paragraphs = []
    cur = element.next
    until cur.nil? or cur['class'] == 'section-history'
      paragraphs.push cur if cur['class'] == 'section-para'
      cur = cur.next
    end
    content = paragraphs.map { |para| para.content }.join('\n')
    
    { :number => number, :title => m[2], :ref_url => url, :content => content }
  end
end


titles.each do |title|
  chapters(title).each do |chapter|
    subchapters(chapter).each do |subchapter|
      sections(chapter[:number], subchapter).each do |section|
        p section
      end
    end
  end
end