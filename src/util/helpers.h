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
#include "itkBinaryThresholdImageFilter.h"
#include "itkImageMaskSpatialObject.h"
#include <itkExtractImageFilter.h>
#include "itkMinimumMaximumImageCalculator.h"

#define ReportFilterMacro(FILTER) ::cascade::util::WriteImage( #FILTER ".nii.gz" , FILTER->GetOutput())


namespace cascade
{

namespace util
{

template< class ImageT >
typename ImageT::RegionType ImageLargestNonZeroRegion(const ImageT* image);

template< class ImageT >
typename ImageT::Pointer CropImage(const ImageT* image,
                                   typename ImageT::RegionType desiredRegion);
template< class ImageT >
typename ImageT::Pointer LoadImage(std::string filename);

template< class ImageT >
void WriteImage(std::string filename, const ImageT* image);

template< class ImageT >
void IsImageProper(const ImageT* image);

bool endsWith(std::string const &fullString, std::string const &ending);


template< class ImageT >
typename ImageT::RegionType ImageLargestNonZeroRegion(const ImageT* image)
  {
  typedef ::itk::ImageMaskSpatialObject< ImageT::ImageDimension > ImageMaskSpatialObjectType;
  typedef ::itk::BinaryThresholdImageFilter<ImageT, typename ImageMaskSpatialObjectType::ImageType> ThresholdFilterType;

  typename ThresholdFilterType::Pointer threshold=ThresholdFilterType::New();
  threshold->SetLowerThreshold(1);
  threshold->SetInput(image);
  threshold->SetOutsideValue(0);
  threshold->SetInsideValue(1);
  threshold->Update();

  typename ImageMaskSpatialObjectType::Pointer imageMaskSpatialObject =
      ImageMaskSpatialObjectType::New();


  imageMaskSpatialObject->SetImage(threshold->GetOutput());
  ::itk::ImageRegion< ImageT::ImageDimension > boundingBoxRegion =
      imageMaskSpatialObject->GetAxisAlignedBoundingBoxRegion();

  return boundingBoxRegion;
  }

template< class ImageT >
typename ImageT::Pointer CropImage(const ImageT* image,
                                   typename ImageT::RegionType desiredRegion)
  {
  typedef ::itk::ExtractImageFilter< ImageT, ImageT > CroppingFilterType;
  typename CroppingFilterType::Pointer croppingFilter = CroppingFilterType::New();
  croppingFilter->SetExtractionRegion(desiredRegion);
  croppingFilter->SetInput(image);
#if ITK_VERSION_MAJOR >= 4
  croppingFilter->SetDirectionCollapseToIdentity();
#endif
  croppingFilter->Update();

  typename ImageT::Pointer output = croppingFilter->GetOutput();
  output->Update();
  output->DisconnectPipeline();
  return output;

  }
template< class ImageT >
typename ImageT::Pointer LoadImage(std::string filename)
  {
  typedef ::itk::ImageFileReader< ImageT > ImageReaderType;
  typename ImageT::Pointer image;
  typename ImageReaderType::Pointer reader = ImageReaderType::New();
  reader->SetFileName(filename);
  image = reader->GetOutput();
  image->Update();
  image->DisconnectPipeline();
  return image;
  }

template< class ImageT >
void WriteImage(std::string filename, const ImageT* image)
  {
  typedef ::itk::ImageFileWriter< ImageT > ImageWriterType;
  typename ImageWriterType::Pointer writer = ImageWriterType::New();
  writer->SetFileName(filename);
  writer->SetInput(image);
  writer->Update();
  }

template< class ImageT >
void IsImageProper(const ImageT* image)
  {
  typedef ::itk::MinimumMaximumImageCalculator< ImageT > ImageCalculatorFilterType;
  typename ImageCalculatorFilterType::Pointer imageCalculatorFilter =
      ImageCalculatorFilterType::New();
  imageCalculatorFilter->SetImage(image);
  imageCalculatorFilter->Compute();
  std::cout << "[" << imageCalculatorFilter->GetMinimum() << ", "
            << imageCalculatorFilter->GetMaximum() << "]" << std::endl;
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
