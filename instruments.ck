/*
-------------------------------------------------- PLAYING TRACKS --------------------------------------------------
I loop all tracks simultaneously, and mute/unmute tracks in order 
to change the overall soundscape. This allows the parts to stay
synced.
*/

SndBuf brass1 => dac;
SndBuf brass2 => dac;
SndBuf drums1 => dac;
SndBuf drums2 => dac;
SndBuf guitar1 => dac;
SndBuf guitar2 => dac;
SndBuf piano1 => dac;
SndBuf piano2 => dac;
SndBuf woodwinds1 => dac;
SndBuf woodwinds2 => dac;
[brass1, brass2, drums1, drums2, guitar1, guitar2, piano1, piano2, woodwinds1, woodwinds2] @=> SndBuf all_sndbufs[];

// All instruments looping and muted by default
for (SndBuf @ sb : all_sndbufs) {
    true => sb.loop;
    0 => sb.gain;
}

"instrument_sounds/brass1.wav" => brass1.read;
"instrument_sounds/brass2.wav" => brass2.read;
"instrument_sounds/drums1.wav" => drums1.read;
"instrument_sounds/drums2.wav" => drums2.read;
"instrument_sounds/guitar1.wav" => guitar1.read;
"instrument_sounds/guitar2.wav" => guitar2.read;
"instrument_sounds/piano1.wav" => piano1.read;
"instrument_sounds/piano2.wav" => piano2.read;
"instrument_sounds/woodwinds1.wav" => woodwinds1.read;
"instrument_sounds/woodwinds2.wav" => woodwinds2.read;

// default mapping of tracks to instruments
drums1 @=> SndBuf @ instrument_A;
woodwinds1 @=> SndBuf @ instrument_B;
piano1 @=> SndBuf @ instrument_X;
guitar2 @=> SndBuf @ instrument_Y;




/*
-------------------------------------------------- CONTROLLER --------------------------------------------------
This section provides the functionality for reading the state of the controller.
*/

// HID input and HID message
Hid hi;
HidMsg msg;

// which joystick
0 => int device;
// get from command line
if( me.args() ) me.arg(0) => Std.atoi => device;

// open joystick 0, exit on fail
if( !hi.openJoystick( device ) ) me.exit();

<<< "joystick '" + hi.name() + "' ready", "" >>>;


// "which" numbers for each controller button
0 => int A;
1 => int B;
3 => int X;
4 => int Y;
6 => int LB;
7 => int RB;

// current state of buttons
false => int A_PRESSED;   // track A
false => int B_PRESSED;   // track B
false => int X_PRESSED;   // track X
false => int Y_PRESSED;   // track Y
false => int LB_PRESSED;  // select instrument for held track
false => int RB_PRESSED;  // switch section (section 1 or 2) for held track(s)


// allow for muting/unmuting of tracks. If LB or RB is pressed in between [track] button down and up, dont allow mute
false => int MUTE_A;
false => int MUTE_B;
false => int MUTE_X;
false => int MUTE_Y;

// allow for switching track sections
false => int SWITCH_SECTION;

// allow for selecting instrument
false => int SELECT_INSTRUMENT;
false => int SELECT_INSTRUMENT_A;
false => int SELECT_INSTRUMENT_B;
false => int SELECT_INSTRUMENT_X;
false => int SELECT_INSTRUMENT_Y;

6 => int SELECTED_INSTRUMENT_IDX;       // value will be updated by calls to select_instrument()

fun void switch_section(SndBuf @ instrument, string track) {
    SndBuf @ new_section;
    if (instrument == brass1) brass2 @=> new_section;
    else if (instrument == brass2) brass1 @=> new_section;
    else if (instrument == drums1) drums2 @=> new_section;
    else if (instrument == drums2) drums1 @=> new_section;
    else if (instrument == guitar1) guitar2 @=> new_section;
    else if (instrument == guitar2) guitar1 @=> new_section;
    else if (instrument == piano1) piano2 @=> new_section;
    else if (instrument == piano2) piano1 @=> new_section;
    else if (instrument == woodwinds1) woodwinds2 @=> new_section;
    else if (instrument == woodwinds2) woodwinds1 @=> new_section;
    else <<< "switch_section(), provided instrument invalid" >>>;

    if (track == "A") new_section @=> instrument_A;
    else if (track == "B") new_section @=> instrument_B;
    else if (track == "X") new_section @=> instrument_X;
    else if (track == "Y") new_section @=> instrument_Y;
}



fun void controller() {
    // infinite event loop
    while( true )
    {
        // wait on HidIn as event
        hi => now;

        // messages received
        while( hi.recv( msg ) )
        {

            // joystick button down
            if( msg.isButtonDown())
            {
                if (msg.which == A) {
                    true => A_PRESSED;
                    true => MUTE_A;
                }
                else if (msg.which == B) {
                    true => B_PRESSED;
                    true => MUTE_B;
                }
                else if (msg.which == X) {
                    true => X_PRESSED;
                    true => MUTE_X;
                }
                else if (msg.which == Y) {
                    true => Y_PRESSED;
                    true => MUTE_Y;
                }
                else if (msg.which == LB) {
                    true => LB_PRESSED;
                    false => MUTE_A;
                    false => MUTE_B;
                    false => MUTE_X;
                    false => MUTE_Y;
                }
                else if (msg.which == RB) {
                    true => RB_PRESSED;
                    true => SWITCH_SECTION;
                    false => MUTE_A;
                    false => MUTE_B;
                    false => MUTE_X;
                    false => MUTE_Y;
                }
            }
            
            // joystick button up
            else if( msg.isButtonUp() )
            {
                if (msg.which == A) false => A_PRESSED;
                else if (msg.which == B) false => B_PRESSED;
                else if (msg.which == X) false => X_PRESSED;
                else if (msg.which == Y) false => Y_PRESSED;
                else if (msg.which == LB) false => LB_PRESSED;
                else if (msg.which == RB) false => RB_PRESSED;
            }
        }
    }
}

spork ~ controller();   // this will run indefinetly, retrieving controller state



/*
-------------------------------------------------- GETTING INSTRUMENT FROM MIC --------------------------------------------------
This section provides functionality for selecting the instrument given mic input.

Code for this section adapted from mosaic-synth-mic.ck (v1.3)

authors: Ge Wang (https://ccrma.stanford.edu/~ge/)
         Kiran Bhat
         Yikai Li
*/

// input: pre-extracted model file
"voice_features.txt" => string FEATURES_FILE;

// ---------------------
// expected model file format; each VALUE is a feature value
// (feel free to adapt and modify the file format as needed)
// ---------------------
// filePath windowStartTime VALUE VALUE ... VALUE
// filePath windowStartTime VALUE VALUE ... VALUE
// ...
// filePath windowStartTime VALUE VALUE ... VALUE
// ---------------------


// ---------------------
// unit analyzer network: *** this must match the features in the features file
// ---------------------
// audio input into a FFT
adc => FFT fft;
// a thing for collecting multiple features into one vector
FeatureCollector combo => blackhole;
// add spectral feature: Centroid
fft =^ Centroid centroid =^ combo;
// add spectral feature: Flux
fft =^ Flux flux =^ combo;
// add spectral feature: RMS
fft =^ RMS rms =^ combo;
// add spectral feature: MFCC
fft =^ MFCC mfcc =^ combo;


// ---------------------
// setting analysis parameters -- also should match what was used during extration
// ---------------------
// set number of coefficients in MFCC (how many we get out)
// 13 is a commonly used value; using less here for printing
20 => mfcc.numCoeffs;
// set number of mel filters in MFCC
10 => mfcc.numFilters;

// do one .upchuck() so FeatureCollector knows how many total dimension
combo.upchuck();
// get number of total feature dimensions
combo.fvals().size() => int NUM_DIMENSIONS;

// set FFT size
4096 => fft.size;


// set window type and size
Windowing.hann(fft.size()) => fft.window;
// our hop size (how often to perform analysis)
(fft.size()/2)::samp => dur HOP;
// 500::ms => dur HOP;
// how many frames to aggregate before averaging?
// (this does not need to match extraction; might play with this number)
4 => int NUM_FRAMES;
// how much time to aggregate features for each file
fft.size()::samp * NUM_FRAMES => dur EXTRACT_TIME;


// ---------------------
// load feature data; read important global values like numPoints and numCoeffs
// ---------------------
// values to be read from file
0 => int numPoints; // number of points in data
0 => int numCoeffs; // number of dimensions in data
// file read PART 1: read over the file to get numPoints and numCoeffs
loadFile( FEATURES_FILE ) @=> FileIO @ fin;
// check
if( !fin.good() ) me.exit();
// check dimension at least
if( numCoeffs != NUM_DIMENSIONS )
{
    // error
    <<< "[error] expecting:", NUM_DIMENSIONS, "dimensions; but features file has:", numCoeffs >>>;
    // stop
    me.exit();
}


// ---------------------
// each AudioWindow corresponds to one line in the input file, which is one audio window
// ---------------------
class AudioWindow
{
    // unique point index (use this to lookup feature vector)
    int uid;
    // which file did this come file (in files arary)
    int fileIndex;
    // starting time in that file (in seconds)
    float windowTime;
    
    // set
    fun void set( int id, int fi, float wt )
    {
        id => uid;
        fi => fileIndex;
        wt => windowTime;
    }
}

// array of all points in model file
AudioWindow windows[numPoints];
// unique filenames; we will append to this
string files[0];
// map of filenames loaded
int filename2state[0];
// feature vectors of data points
float inFeatures[numPoints][numCoeffs];
// generate array of unique indices
int uids[numPoints]; for( int i; i < numPoints; i++ ) i => uids[i];

// use this for new input
float features[NUM_FRAMES][numCoeffs];
// average values of coefficients across frames
float featureMean[numCoeffs];


// ---------------------
// read the data
// ---------------------
readData( fin );


// ---------------------
// set up our KNN object to use for classification
// (KNN2 is a fancier version of the KNN object)
// -- run KNN2.help(); in a separate program to see its available functions --
// ---------------------
KNN2 knn;
// k nearest neighbors
2 => int K;
// results vector (indices of k nearest points)
int knnResult[K];
// knn train
knn.train( inFeatures, uids );


// ---------------------
// function: real-time similarity retrieval of single filename
// ---------------------

fun string retrieve_filename()
{
    // aggregate features over a period of time
    for( int frame; frame < NUM_FRAMES; frame++ )
    {
        // ---------------------
        // a single upchuck() will trigger analysis on everything
        // connected upstream from combo via the upchuck operator (=^)
        // the total number of output dimensions is the sum of
        // dimensions of all the connected unit analyzers
        // ---------------------
        combo.upchuck();  
        // get features
        for( int d; d < NUM_DIMENSIONS; d++) 
        {
            // store them in current frame
            combo.fval(d) => features[frame][d];
        }
        // advance time
        HOP => now;
    }
    
    // compute means for each coefficient across frames
    for( int d; d < NUM_DIMENSIONS; d++ )
    {
        // zero out
        0.0 => featureMean[d];
        // loop over frames
        for( int j; j < NUM_FRAMES; j++ )
        {
            // add
            features[j][d] +=> featureMean[d];
        }
        // average
        NUM_FRAMES /=> featureMean[d];
    }
    
    // ---------------------
    // search using KNN2; results filled in knnResults,
    // which should the indices of k nearest points
    // ---------------------
    knn.search( featureMean, K, knnResult );
        
    // GET NEAREST NEIGHBORS'S FILENAME
    knnResult[Math.random2(0,knnResult.size()-1)] => int temp;
    windows[temp] @=> AudioWindow @ win;
    // get filename
    files[win.fileIndex] => string filename;
    <<< "filename:", filename >>>;
    return filename;
}


// ---------------------
// function: select instrument
// - This function is meant to be sporked -- will exit once it escapes the while loop (i.e. when select-instrument button is released)
// - This function tries to predict which instrument the user is mimicking into the mic, and returns it's index
// ---------------------
Event wait_for_instrument_selection;
fun void select_instrument() {
    0 => int brass1_count;
    0 => int brass2_count;
    0 => int drums1_count;
    0 => int drums2_count;
    0 => int guitar1_count;
    0 => int guitar2_count;
    0 => int piano1_count;
    0 => int piano2_count;
    0 => int woodwinds1_count;
    0 => int woodwinds2_count;

    while (SELECT_INSTRUMENT) {         // check if controller state is to select an instrument. If not, exit the loop
        retrieve_filename() => string filename;
        if (filename == "voice_sounds/brass1.wav") brass1_count + 1 => brass1_count;
        else if (filename == "voice_sounds/brass2.wav") brass2_count + 1 => brass2_count;
        else if (filename == "voice_sounds/drums1.wav") drums1_count + 1 => drums1_count;
        else if (filename == "voice_sounds/drums2.wav") drums2_count + 1 => drums2_count;
        else if (filename == "voice_sounds/guitar1.wav") guitar1_count + 1 => guitar1_count;
        else if (filename == "voice_sounds/guitar2.wav") guitar2_count + 1 => guitar2_count;
        else if (filename == "voice_sounds/piano1.wav") piano1_count + 1 => piano1_count;
        else if (filename == "voice_sounds/piano2.wav") piano2_count + 1 => piano2_count;
        else if (filename == "voice_sounds/woodwinds1.wav") woodwinds1_count + 1 => woodwinds1_count;
        else if (filename == "voice_sounds/woodwinds2.wav") woodwinds2_count + 1 => woodwinds2_count;
    }

    [brass1_count, brass2_count, drums1_count, drums2_count, guitar1_count, guitar2_count, piano1_count, piano2_count, woodwinds1_count, woodwinds2_count] @=> int counts[];

    // get max count instrument
    0 => int max_count;
    6 => int max_count_idx;
    for (0 => int i; i < counts.cap(); i++) {
        if (counts[i] > max_count) {
            i => max_count_idx;
            counts[i] => max_count;
        } 
    }

    <<< "count brass1", counts[0] >>>;
    <<< "count brass2", counts[1] >>>;
    <<< "count drums1", counts[2] >>>;
    <<< "count drums2", counts[3] >>>;
    <<< "count guitar1", counts[4] >>>;
    <<< "count guitar2", counts[5] >>>;
    <<< "count piano1", counts[6] >>>;
    <<< "count piano2", counts[7] >>>;
    <<< "count woodwinds1", counts[8] >>>;
    <<< "count woodwinds2", counts[9] >>>;

    max_count_idx => SELECTED_INSTRUMENT_IDX;  // use the max count instrument as our selected instrument (which can be obtained from all_sndbufs array)
    <<< "~ selected instrument idx:", SELECTED_INSTRUMENT_IDX >>>;
    wait_for_instrument_selection.signal();
}


// ---------------------
// function: load data file
// ---------------------
fun FileIO loadFile( string filepath )
{
    // reset
    0 => numPoints;
    0 => numCoeffs;
    
    // load data
    FileIO fio;
    if( !fio.open( filepath, FileIO.READ ) )
    {
        // error
        <<< "cannot open file:", filepath >>>;
        // close
        fio.close();
        // return
        return fio;
    }
    
    string str;
    string line;
    // read the first non-empty line
    while( fio.more() )
    {
        // read each line
        fio.readLine().trim() => str;
        // check if empty line
        if( str != "" )
        {
            numPoints++;
            str => line;
        }
    }
    
    // a string tokenizer
    StringTokenizer tokenizer;
    // set to last non-empty line
    tokenizer.set( line );
    // negative (to account for filePath windowTime)
    -2 => numCoeffs;
    // see how many, including label name
    while( tokenizer.more() )
    {
        tokenizer.next();
        numCoeffs++;
    }
    
    // see if we made it past the initial fields
    if( numCoeffs < 0 ) 0 => numCoeffs;
    
    // check
    if( numPoints == 0 || numCoeffs <= 0 )
    {
        <<< "no data in file:", filepath >>>;
        fio.close();
        return fio;
    }
    
    // print
    <<< "# of data points:", numPoints, "dimensions:", numCoeffs >>>;
    
    // done for now
    return fio;
}


// ---------------------
// function: read the data
// ---------------------
fun void readData( FileIO fio )
{
    // rewind the file reader
    fio.seek( 0 );
    
    // a line
    string line;
    // a string tokenizer
    StringTokenizer tokenizer;
    
    // points index
    0 => int index;
    // file index
    0 => int fileIndex;
    // file name
    string filename;
    // window start time
    float windowTime;
    // coefficient
    int c;
    
    // read the first non-empty line
    while( fio.more() )
    {
        // read each line
        fio.readLine().trim() => line;
        // check if empty line
        if( line != "" )
        {
            // set to last non-empty line
            tokenizer.set( line );
            // file name
            tokenizer.next() => filename;
            // window start time
            tokenizer.next() => Std.atof => windowTime;
            // have we seen this filename yet?
            if( filename2state[filename] == 0 )
            {
                // make a new string (<< appends by reference)
                filename => string sss;
                // append
                files << sss;
                // new id
                files.size() => filename2state[filename];
            }
            // get fileindex
            filename2state[filename]-1 => fileIndex;
            // set
            windows[index].set( index, fileIndex, windowTime );

            // zero out
            0 => c;
            // for each dimension in the data
            repeat( numCoeffs )
            {
                // read next coefficient
                tokenizer.next() => Std.atof => inFeatures[index][c];
                // increment
                c++;
            }
            
            // increment global index
            index++;
        }
    }
}


/*
-------------------------------------------------- CONTROLLER BUTTON LOGIC LOOP --------------------------------------------------
Should the current state cause:
1. muting/unmuting of a specific track?
2. switching sections of a specific track?
3. starting/ending instrument selection for a specific track?
*/
while (true) {
    // --- 1. muting and unmuting tracks ---
    if (!A_PRESSED && MUTE_A) {
        false => MUTE_A;
        <<< "MUTE/UNMUTE A" >>>;
        if (instrument_A.gain() > 0.5) 0 => instrument_A.gain;      // 0.5 to prevent floating point errors
        else 1 => instrument_A.gain;
        
    }
    if (!B_PRESSED && MUTE_B) {
        false => MUTE_B;
        <<< "MUTE/UNMUTE B" >>>;
        if (instrument_B.gain() > 0.5) 0 => instrument_B.gain;
        else 1 => instrument_B.gain;
        
    }
    if (!X_PRESSED && MUTE_X) {
        false => MUTE_X;
        <<< "MUTE/UNMUTE X" >>>;
        if (instrument_X.gain() > 0.5) 0 => instrument_X.gain;
        else 1 => instrument_X.gain;
    }
    if (!Y_PRESSED && MUTE_Y) {
        false => MUTE_Y;
        <<< "MUTE/UNMUTE Y" >>>;
        if (instrument_Y.gain() > 0.5) 0 => instrument_Y.gain;
        else 1 => instrument_Y.gain;
    }

    // --- 2. track section switching ---
    if (!RB_PRESSED && SWITCH_SECTION) {
        false => SWITCH_SECTION;        // switch occurred, so disable switching for next while loop iteration
        if (A_PRESSED) {
            <<< "SWITCH SECTION ON A" >>>;
            instrument_A.gain() => float current_gain;
            0 => instrument_A.gain;
            switch_section(instrument_A, "A");
            current_gain => instrument_A.gain;
        }
        if (B_PRESSED) {
            <<< "SWITCH SECTION ON B" >>>;
            instrument_B.gain() => float current_gain;
            0 => instrument_B.gain;
            switch_section(instrument_B, "B");
            current_gain => instrument_B.gain;
        }
        if (X_PRESSED) {
            <<< "SWITCH SECTION ON X" >>>;
            instrument_X.gain() => float current_gain;
            0 => instrument_X.gain;
            switch_section(instrument_X, "X");
            current_gain => instrument_X.gain;
        }
        if (Y_PRESSED) {
            <<< "SWITCH SECTION ON Y" >>>;
            instrument_Y.gain() => float current_gain;
            0 => instrument_Y.gain;
            switch_section(instrument_Y, "Y");
            current_gain => instrument_Y.gain;
        }
    }

    // --- 3. track instrument selection ---
    if (LB_PRESSED && !SELECT_INSTRUMENT) {
        true => SELECT_INSTRUMENT;
        if (A_PRESSED) {
            true => SELECT_INSTRUMENT_A;        // need these in case user lets go of A before releasing LB
            <<< "START INSTRUMENT SELECTION ON A" >>>;
            // maybe mute A to make selection easier?
            0 => instrument_A.gain;
            spork ~ select_instrument();
        }
        else if (B_PRESSED) {
            true => SELECT_INSTRUMENT_B;
            <<< "START INSTRUMENT SELECTION ON B" >>>;
            // maybe mute B to make selection easier?
            0 => instrument_B.gain;
            spork ~ select_instrument();
        }
        else if (X_PRESSED) {
            true => SELECT_INSTRUMENT_X;
            <<< "START INSTRUMENT SELECTION ON X" >>>;
            // maybe mute X to make selection easier?
            0 => instrument_X.gain;
            spork ~ select_instrument();
        }
        else if (Y_PRESSED) {
            true => SELECT_INSTRUMENT_Y;
            <<< "START INSTRUMENT SELECTION ON Y" >>>;
            // maybe mute Y to make selection easier?
            0 => instrument_Y.gain;
            spork ~ select_instrument();        // pasted 4 times to prevent race condition
        }
    }

    
    else if (!LB_PRESSED && SELECT_INSTRUMENT) {
        false => SELECT_INSTRUMENT;                 // this line allows ~select_instrument() to finish, and preps controller state for next instrument selection
        if (SELECT_INSTRUMENT_A) {
            false => SELECT_INSTRUMENT_A;
            <<< "END INSTRUMENT SELECTION ON A" >>>;
            // wait for instrument to finish being selected (i.e. for ~select_instrument() to finish execution)
            wait_for_instrument_selection => now;
            all_sndbufs[SELECTED_INSTRUMENT_IDX] @=> instrument_A;
            1 => instrument_A.gain;
        }
        else if (SELECT_INSTRUMENT_B) {
            false => SELECT_INSTRUMENT_B;
            <<< "END INSTRUMENT SELECTION ON B" >>>;
            // wait for instrument to finish being selected (i.e. for ~select_instrument() to finish execution)
            wait_for_instrument_selection => now;
            all_sndbufs[SELECTED_INSTRUMENT_IDX] @=> instrument_B;
            1 => instrument_B.gain;
        }
        else if (SELECT_INSTRUMENT_X) {
            false => SELECT_INSTRUMENT_X;
            <<< "END INSTRUMENT SELECTION ON X" >>>;
            // wait for instrument to finish being selected (i.e. for ~select_instrument() to finish execution)
            wait_for_instrument_selection => now;
            all_sndbufs[SELECTED_INSTRUMENT_IDX] @=> instrument_X;
            1 => instrument_X.gain;
        }
        else if (SELECT_INSTRUMENT_Y) {
            false => SELECT_INSTRUMENT_Y;
            <<< "END INSTRUMENT SELECTION ON Y" >>>;
            // wait for instrument to finish being selected (i.e. for ~select_instrument() to finish execution)
            wait_for_instrument_selection => now;
            all_sndbufs[SELECTED_INSTRUMENT_IDX] @=> instrument_Y;
            1 => instrument_Y.gain;
        }
    }

    100::ms => now;
}



