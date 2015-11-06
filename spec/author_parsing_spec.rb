require 'author_parsing'
require 'spec_helper'

describe AuthorParsing do
  let(:author_string) { '' }

  subject { AuthorParsing.parse_author_string(author_string) }

  it { should eq([]) }

  let_context(author_string: 'Myke Hurley and CGP Grey') { it { should eq ['Myke Hurley', 'CGP Grey'] } }

  let_context(author_string: 'Diane A. Haydon') { it { should eq ['Diane A. Haydon'] } }
  let_context(author_string: 'Diane Haydon') { it { should eq ['Diane Haydon'] } }

  let_context(author_string: 'Diane Haydon and Donald S. Just') { it { should eq ['Diane Haydon', 'Donald S. Just'] } }
  let_context(author_string: 'Diane Haydon, Donald S. Just') { it { should eq ['Diane Haydon', 'Donald S. Just'] } }
  let_context(author_string: 'Diane Haydon; Donald S. Just') { it { should eq ['Diane Haydon', 'Donald S. Just'] } }
  let_context(author_string: 'Diane Haydon & Donald S. Just') { it { should eq ['Diane Haydon', 'Donald S. Just'] } }
  let_context(author_string: 'Diane Haydon &amp; Donald S. Just') { it { should eq ['Diane Haydon', 'Donald S. Just'] } }

  let_context(author_string: 'Gabe Weatherhead and Jeff Hunsberger (Gravity Well Group, LLC)') { it { should eq ['Gabe Weatherhead', 'Jeff Hunsberger'] } }

  let_context(author_string: 'fanboysonfiction@gmail.com (Roger Colby &amp; Ryan McKinley)') { it { should eq ['Roger Colby', 'Ryan McKinley'] } }

  let_context(author_string: 'Daniel J. Lewis, Jeremy Laughlin, Erin, Hunter Hathaway, and Jacquelyn - Once Upon a Time reviewers') do
    it { should eq ['Daniel J. Lewis', 'Jeremy Laughlin', 'Erin', 'Hunter Hathaway', 'Jacquelyn'] }
  end

  let_context(author_string: 'Disney-ABC Television Group Digital Broadcast Communications and Production') { it { should eq [] } }
  let_context(author_string: 'Nerd Herd') { it { should eq [] } }
  let_context(author_string: 'Nerds to the Nth Degree!  | We Talk Movies/TV, Comic Books, Metal, etc. Interviews: Kevin Eastman(TMNT), Wolfcop. Similar to Nerdist, Hollywood Babble-On, SMODCast, Talk Salad, Tell \'em Steve-Dave! Check Out Our Fear the Walking Dead') { it { should eq ['Kevin Eastman', 'Wolfcop'] } }

  let_context(author_string: 'Drew, Myles &amp; Patrick') { it { should eq ['Drew', 'Myles', 'Patrick'] } }

  let_context(author_string: 'Mike Vardy: Productivity Strategist | Time Management Specialist | To Do List Hacker') do
    it { should eq ['Mike Vardy'] }
  end

  let_context(author_string: 'The Once And Future Nerd, Matthew McLean, Audio Drama Production Podcast') { it { should eq ['Matthew McLean'] } }
  let_context(author_string: 'We Talk movies/Tv, Comic Books, Music, etc. Similar to Nerdist, Hollywood Babble-on, SMODCAST, Kevin Smith, I Sell Comics') { it { should eq('Kevin Smith') } }

  let_context(author_string: 'Wlliam Carrol') { it { should eq ['Wlliam Carrol'] } }
end

