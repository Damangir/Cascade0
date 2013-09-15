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
#include "buildinfo.h"
/*
 * CPP Headers
 */
#include <vector>
#include <string>
/*
 * General ITK
 */
#include "itkImage.h"
/*
 * ITK Filters
 */
#include "itkBinaryThresholdImageFilter.h"
#include "itkBinaryImageToShapeLabelMapFilter.h"
#include "itkShapeOpeningLabelMapFilter.h"
#include "itkLabelMapToLabelImageFilter.h"

/*
 * ITK IO
 */
#include "itkImageFileReader.h"
#include "itkImageFileWriter.h"

/*
 * Others
 */
#include "util/helpers.h"
#include "3rdparty/tclap/CmdLine.h"
/*
 * Pixel types
 */
typedef unsigned int PixelType;
typedef unsigned int LabelType;
/*
 * Image types
 */
typedef itk::Image< PixelType, DIM > ImageType;
typedef itk::Image< LabelType, DIM > LabelImageType;

typedef itk::BinaryThresholdImageFilter< ImageType, ImageType > BinaryThresholdImageFilterType;
typedef itk::BinaryImageToShapeLabelMapFilter< ImageType > BinaryImageToShapeLabelMapFilterType;
typedef BinaryImageToShapeLabelMapFilterType::OutputImageType ShapeLabelMapType;
typedef itk::ShapeOpeningLabelMapFilter< ShapeLabelMapType > ShapeOpeningLabelMapFilterType;
typedef itk::LabelMapToLabelImageFilter< ShapeLabelMapType, LabelImageType > LabelMapToLabelImageFilterType;

/*
 * IO types
 */
typedef itk::ImageFileWriter< ImageType > WriterType;

int main(int argc, char *argv[])
  {
  TCLAP::CmdLine cmd(
      "Cascade(v" CASCADE_VERSION ") - Segmentation of White Matter Lesion. Image intensity range controller " BUILDINFO,
      ' ', CASCADE_VERSION);

  TCLAP::ValueArg< std::string > outfile("o", "out", "Output filename", false,
                                         "out.nii.gz", "string", cmd);

  TCLAP::SwitchArg reverseSwitch("r", "reverse", "Threshold backwards", cmd,
                                 false);

  TCLAP::ValueArg< float > threshold("t", "threshold",
                                     "property to be filtered. ", false, 0.0,
                                     "Threshold", cmd);

  std::vector< std::string > allowedProperty;
  allowedProperty.push_back("NumberOfPixels");
  allowedProperty.push_back("PhysicalSize");
  allowedProperty.push_back("Perimeter");
  allowedProperty.push_back("NumberOfPixelsOnBorder");
  allowedProperty.push_back("PerimeterOnBorder");
  allowedProperty.push_back("PerimeterOnBorderRatio");
  allowedProperty.push_back("Elongation");
  allowedProperty.push_back("Flatness");
  allowedProperty.push_back("Roundness");
  allowedProperty.push_back("EquivalentSphericalRadius");
  allowedProperty.push_back("EquivalentSphericalPerimeter");
  allowedProperty.push_back("EquivalentEllipsoidDiameter");
  allowedProperty.push_back("FeretDiameter");
  TCLAP::ValuesConstraint< std::string > allowedVals(allowedProperty);
  TCLAP::ValueArg< std::string > property("", "property",
                                          "Property to be filtered.", false,
                                          "NumberOfPixels", &allowedVals, cmd);

  TCLAP::ValueArg< std::string > input("i", "input",
                                       "Input sequences e.g. MPRAGE.nii.gz",
                                       true, "", "string", cmd);

  /*
   * Parse the argv array.
   */
  try
    {
    cmd.parse(argc, argv);
    }
  catch (TCLAP::ArgException &e)
    {
    std::ostringstream errorMessage;
    errorMessage << "error: " << e.error() << " for arg " << e.argId()
                 << std::endl;
    itk::OutputWindowDisplayErrorText(errorMessage.str().c_str());
    return EXIT_FAILURE;
    }

  /*
   * Argument and setting up the pipeline
   */
  try
    {
    const PixelType thrVal = 0;
    const PixelType foreground = 1;

    ImageType* inputIMage = cascade::util::LoadImage<ImageType>(input.getValue());
    BinaryThresholdImageFilterType::Pointer thresholdFilter =
        BinaryThresholdImageFilterType::New();
    thresholdFilter->SetInput(inputIMage);
    thresholdFilter->SetLowerThreshold(thrVal);
    thresholdFilter->SetInsideValue(foreground);
    thresholdFilter->SetOutsideValue(thrVal);

    BinaryImageToShapeLabelMapFilterType::Pointer binaryImageToShapeLabelMapFilter =
        BinaryImageToShapeLabelMapFilterType::New();
    binaryImageToShapeLabelMapFilter->SetInputForegroundValue(foreground);
    binaryImageToShapeLabelMapFilter->SetInput(inputIMage);
    binaryImageToShapeLabelMapFilter->Update();

    /** Statistics on image should be reported */
    if (outfile.getValue() == "-")
      {
      std::cout << "NumberOfPixels" << ", ";
      std::cout << "PhysicalSize" << ", ";
      std::cout << "Perimeter" << ", ";
      std::cout << "Elongation" << ", ";
      std::cout << "Roundness" << ", ";
      for (int i=0;i<DIM;i++)
      std::cout << "Centroid[" << i << "], ";

      std::cout << "EquivalentSphericalRadius" << ", ";
      std::cout << "EquivalentSphericalPerimeter";
      std::cout << std::endl;

      ShapeLabelMapType* shapeLabel =
          binaryImageToShapeLabelMapFilter->GetOutput();
      ShapeLabelMapType::Iterator shapeIterator(shapeLabel);
      while (!shapeIterator.IsAtEnd())
        {
        ShapeLabelMapType::LabelObjectType* labelObject =
            shapeIterator.GetLabelObject();
        std::cout << labelObject->GetNumberOfPixels() << ", ";
        std::cout << labelObject->GetPhysicalSize() << ", ";
        std::cout << labelObject->GetPerimeter() << ", ";
        std::cout << labelObject->GetElongation() << ", ";
        std::cout << labelObject->GetRoundness() << ", ";

        for (int i=0;i<DIM;i++)
        std::cout << labelObject->GetCentroid()[i] << ", ";

        std::cout << labelObject->GetEquivalentSphericalRadius() << ", ";
        std::cout << labelObject->GetEquivalentSphericalPerimeter();
        std::cout << std::endl;
        ++shapeIterator;
        }
      }
    else
      {
      ShapeOpeningLabelMapFilterType::Pointer shapeOpeningLabelMapFilter =
          ShapeOpeningLabelMapFilterType::New();
      shapeOpeningLabelMapFilter->SetInput(
          binaryImageToShapeLabelMapFilter->GetOutput());
      shapeOpeningLabelMapFilter->SetReverseOrdering(reverseSwitch.getValue());
      shapeOpeningLabelMapFilter->SetLambda(threshold.getValue());
      shapeOpeningLabelMapFilter->SetAttribute(property.getValue());
      shapeOpeningLabelMapFilter->Update();

      LabelMapToLabelImageFilterType::Pointer labelMapToLabelImageFilter =
          LabelMapToLabelImageFilterType::New();
      labelMapToLabelImageFilter->SetInput(
          shapeOpeningLabelMapFilter->GetOutput());
      labelMapToLabelImageFilter->Update();

      thresholdFilter->SetInput(labelMapToLabelImageFilter->GetOutput());
      thresholdFilter->SetLowerThreshold(thrVal + 1);
      thresholdFilter->SetInsideValue(foreground);
      thresholdFilter->SetOutsideValue(thrVal);

      WriterType::Pointer writer = WriterType::New();
      writer->SetInput(thresholdFilter->GetOutput());
      writer->SetFileName(outfile.getValue());
      writer->Update();
      }

    }
  catch (itk::ExceptionObject & err)
    {
    std::ostringstream errorMessage;
    errorMessage << "Exception caught!\n" << err << "\n";
    itk::OutputWindowDisplayErrorText(errorMessage.str().c_str());
    return EXIT_FAILURE;
    }

  return EXIT_SUCCESS;
  }
