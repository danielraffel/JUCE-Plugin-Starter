#include "PluginProcessor.h"
#include "PluginEditor.h"

//==============================================================================
CLASS_NAME_PLACEHOLDERAudioProcessor::CLASS_NAME_PLACEHOLDERAudioProcessor()
    : AudioProcessor (BusesProperties()
                      .withInput  ("Input",  juce::AudioChannelSet::stereo(), true)
                      .withOutput ("Output", juce::AudioChannelSet::stereo(), true))
{
}

CLASS_NAME_PLACEHOLDERAudioProcessor::~CLASS_NAME_PLACEHOLDERAudioProcessor()
{
}

const juce::String CLASS_NAME_PLACEHOLDERAudioProcessor::getName() const
{
    return JucePlugin_Name;
}

bool CLASS_NAME_PLACEHOLDERAudioProcessor::acceptsMidi() const
{
   #if JucePlugin_WantsMidiInput
    return true;
   #else
    return false;
   #endif
}

bool CLASS_NAME_PLACEHOLDERAudioProcessor::producesMidi() const
{
   #if JucePlugin_ProducesMidiOutput
    return true;
   #else
    return false;
   #endif
}

bool CLASS_NAME_PLACEHOLDERAudioProcessor::isMidiEffect() const
{
   #if JucePlugin_IsMidiEffect
    return true;
   #else
    return false;
   #endif
}

double CLASS_NAME_PLACEHOLDERAudioProcessor::getTailLengthSeconds() const
{
    return 0.0;
}

int CLASS_NAME_PLACEHOLDERAudioProcessor::getNumPrograms()
{
    return 1;
}

int CLASS_NAME_PLACEHOLDERAudioProcessor::getCurrentProgram()
{
    return 0;
}

void CLASS_NAME_PLACEHOLDERAudioProcessor::setCurrentProgram (int index)
{
    juce::ignoreUnused (index);
}

const juce::String CLASS_NAME_PLACEHOLDERAudioProcessor::getProgramName (int index)
{
    juce::ignoreUnused (index);
    return {};
}

void CLASS_NAME_PLACEHOLDERAudioProcessor::changeProgramName (int index, const juce::String& newName)
{
    juce::ignoreUnused (index, newName);
}

void CLASS_NAME_PLACEHOLDERAudioProcessor::prepareToPlay (double sampleRate, int samplesPerBlock)
{
    juce::ignoreUnused (sampleRate, samplesPerBlock);
}

void CLASS_NAME_PLACEHOLDERAudioProcessor::releaseResources()
{
}

bool CLASS_NAME_PLACEHOLDERAudioProcessor::isBusesLayoutSupported (const BusesLayout& layouts) const
{
    if (layouts.getMainOutputChannelSet() != juce::AudioChannelSet::mono()
     && layouts.getMainOutputChannelSet() != juce::AudioChannelSet::stereo())
        return false;

    if (layouts.getMainOutputChannelSet() != layouts.getMainInputChannelSet())
        return false;

    return true;
}

void CLASS_NAME_PLACEHOLDERAudioProcessor::processBlock (juce::AudioBuffer<float>& buffer,
                                              juce::MidiBuffer& midiMessages)
{
    juce::ignoreUnused (midiMessages);

    juce::ScopedNoDenormals noDenormals;
    auto totalNumInputChannels  = getTotalNumInputChannels();
    auto totalNumOutputChannels = getTotalNumOutputChannels();

    for (auto i = totalNumInputChannels; i < totalNumOutputChannels; ++i)
        buffer.clear (i, 0, buffer.getNumSamples());

    // This is where you'd add your audio processing code
    for (int channel = 0; channel < totalNumInputChannels; ++channel)
    {
        auto* channelData = buffer.getWritePointer (channel);
        juce::ignoreUnused (channelData);
    }
}

bool CLASS_NAME_PLACEHOLDERAudioProcessor::hasEditor() const
{
    return true;
}

juce::AudioProcessorEditor* CLASS_NAME_PLACEHOLDERAudioProcessor::createEditor()
{
    return new CLASS_NAME_PLACEHOLDERAudioProcessorEditor (*this);
}

void CLASS_NAME_PLACEHOLDERAudioProcessor::getStateInformation (juce::MemoryBlock& destData)
{
    juce::ignoreUnused (destData);
}

void CLASS_NAME_PLACEHOLDERAudioProcessor::setStateInformation (const void* data, int sizeInBytes)
{
    juce::ignoreUnused (data, sizeInBytes);
}

//==============================================================================
// Path Helper Functions - Use macOS Application Support (no permission prompts)
//
// These functions provide standard paths for plugin data following Apple's
// Human Interface Guidelines. Using Application Support prevents permission
// dialogs during installation.
//
// Example usage:
//   auto samplesDir = CLASS_NAME_PLACEHOLDERAudioProcessor::getSamplesPath();
//   if (!samplesDir.exists())
//       samplesDir.createDirectory();
//

juce::File CLASS_NAME_PLACEHOLDERAudioProcessor::getApplicationSupportPath()
{
    auto appSupport = juce::File::getSpecialLocation(
        juce::File::userApplicationDataDirectory
    );

    auto projectFolder = appSupport.getChildFile(JucePlugin_Name);

    // Create if doesn't exist
    if (!projectFolder.exists())
        projectFolder.createDirectory();

    return projectFolder;
}

juce::File CLASS_NAME_PLACEHOLDERAudioProcessor::getSamplesPath()
{
    auto samplesDir = getApplicationSupportPath().getChildFile("Samples");

    if (!samplesDir.exists())
        samplesDir.createDirectory();

    return samplesDir;
}

juce::File CLASS_NAME_PLACEHOLDERAudioProcessor::getPresetsPath()
{
    auto presetsDir = getApplicationSupportPath().getChildFile("Presets");

    if (!presetsDir.exists())
        presetsDir.createDirectory();

    return presetsDir;
}

juce::File CLASS_NAME_PLACEHOLDERAudioProcessor::getUserDataPath()
{
    auto userDataDir = getApplicationSupportPath().getChildFile("UserData");

    if (!userDataDir.exists())
        userDataDir.createDirectory();

    return userDataDir;
}

juce::File CLASS_NAME_PLACEHOLDERAudioProcessor::getLogsPath()
{
    // Logs go to ~/Library/Logs/PluginName (standard macOS location)
    auto home = juce::File::getSpecialLocation(juce::File::userHomeDirectory);
    auto logsDir = home.getChildFile("Library").getChildFile("Logs").getChildFile(JucePlugin_Name);

    if (!logsDir.exists())
        logsDir.createDirectory();

    return logsDir;
}

juce::AudioProcessor* JUCE_CALLTYPE createPluginFilter()
{
    return new CLASS_NAME_PLACEHOLDERAudioProcessor();
}
