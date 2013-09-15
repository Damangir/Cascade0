/*
 * Copyright (C) 2013 Soheil Damangir - All Rights Reserved
 * You may use and distribute, but not modify this code under the terms of the
 * Creative Commons Attribution-NonCommercial-NoDerivs 3.0 Unported License
 * under the following conditions:
 *
 * Attribution — You must attribute the work in the manner specified by the
 * author or licensor (but not in any way that suggests that they endorse you
 * or your use of the work).
 * Noncommercial — You may not use this work for commercial purposes.
 * No Derivative Works — You may not alter, transform, or build upon this
 * work
 *
 * To view a copy of the license, visit
 * http://creativecommons.org/licenses/by-nc-nd/3.0/
 */

#ifndef HELPERS_H_
#define HELPERS_H_

#include <string>
#include <iostream>
#include "itkImageFileReader.h"
#include "itkImageFileWriter.h"

namespace cascade
{

namespace util
{

template<class ImageT>
typename ImageT::Pointer LoadImage(std::string filename)
  {
  typedef itk::ImageFileReader< ImageT > ImageReaderType;
  typename ImageT::Pointer image;
  typename ImageReaderType::Pointer reader = ImageReaderType::New();
  reader->SetFileName(filename);
  image = reader->GetOutput();
  image->Update();
  image->DisconnectPipeline();
  return image;
  }

template<class ImageT>
void WriteImage(std::string filename, const ImageT* image)
  {
  typedef itk::ImageFileWriter< ImageT > ImageWriterType;
  typename ImageWriterType::Pointer writer = ImageWriterType::New();
  writer->SetFileName(filename);
  writer->SetInputImage(image);
  writer->Update();
  }

bool endsWith(std::string const &fullString, std::string const &ending)
  {
  if (fullString.length() >= ending.length())
    {
    return (0
        == fullString.compare(fullString.length() - ending.length(),
                              ending.length(), ending));
    }
  else
    {
    return false;
    }
  }

}  // namespace util

}  // namespace cascade

#endif /* HELPERS_H_ */
