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
#ifndef __itkIntensityLinearTransform_h
#define __itkIntensityLinearTransform_h

#include <utility>
#include <iterator>
#include <vector>
#include <algorithm>


namespace itk
{

template< typename TInput, typename TOutput >
class IntensityLinearTransform
{
public:
  typedef typename NumericTraits< TInput >::RealType RealType;
  typedef std::pair< TInput, TOutput > FixedPointType;
  typedef std::vector< FixedPointType > FixedPointVectorType;
  typedef std::pair< RealType, RealType > LineSegmentType;
  typedef std::vector< LineSegmentType > LineSegmentVectorType;

  typedef typename FixedPointVectorType::iterator FixedPointIteratorType;
  typedef typename LineSegmentVectorType::iterator LineSegmentsIteratorType;

  IntensityLinearTransform()
    {
    this->m_FixedPoints.push_back(
        std::make_pair< TInput, TOutput >(
            NumericTraits< TInput >::NonpositiveMin(),
            NumericTraits< TOutput >::NonpositiveMin()));

    this->m_LineSegments.push_back(std::make_pair< RealType, RealType >(1, 0));
    this->m_NumSegments = 1;
    }
  ~IntensityLinearTransform()
    {
    }
  void AddFixedPoint(const TInput & x, const TOutput & y)
    {
    if (this->m_FixedPoints.size() < 2)
      {
      this->m_LineSegments.clear();
      }
    /*
     * Find the proper location to insert new set
     */
    FixedPointType new_point = std::make_pair< TInput, TOutput >(x, y);
    FixedPointIteratorType point = std::lower_bound(this->m_FixedPoints.begin(),
                                                    this->m_FixedPoints.end(),
                                                    new_point);
    point = this->m_FixedPoints.insert(point, new_point);

    /*
     * Calculate the next line to insert
     */
    point--;
    LineSegmentsIteratorType line = this->m_LineSegments.begin();
    std::advance(line, std::distance(this->m_FixedPoints.begin(), point));
    LineSegmentType lineSeg;
    lineSeg.first = (y - point->second) / (x - point->first);
    lineSeg.second = y - lineSeg.first * x;
    line = this->m_LineSegments.insert(line, lineSeg);

    if (std::distance(line, this->m_LineSegments.end()) > 1)
      {
      /*
       * Return one step back to change the slopes
       */
      point += 2;
      line += 1;
      line->first = (y - point->second) / (x - point->first);
      line->second = y - line->first * x;
      }
    this->m_NumSegments = this->m_LineSegments.size();
    }
  bool operator!=(const IntensityLinearTransform & other) const
    {
    if (std::equal(this->m_FixedPoints.begin(), this->m_FixedPoints.end(),
                   other.m_FixedPoints.begin()))
      {
      return true;
      }
    return false;
    }

  bool operator==(const IntensityLinearTransform & other) const
    {
    return !(*this != other);
    }

  inline TOutput operator()(const TInput & x) const
    {
    for (unsigned int i = 1; i < this->m_NumSegments; i++)
      {
      if (this->m_FixedPoints[i].first > x)
        {
        const std::pair< RealType, RealType >& lineSeg =
            this->m_LineSegments.at(i - 1);
        return lineSeg.first * x + lineSeg.second;
        }
      }

    const std::pair< RealType, RealType >& lineSeg =
        this->m_LineSegments.back();
    return lineSeg.first * x + lineSeg.second;

    }
  template< typename T1, typename T2 > friend std::ostream& operator<<(
      std::ostream &out, IntensityLinearTransform< T1, T2 > &transform);
private:
  FixedPointVectorType m_FixedPoints;
  LineSegmentVectorType m_LineSegments;
  unsigned int m_NumSegments;
};

template< typename TInput, typename TOutput >
std::ostream& operator<<(
    std::ostream &os,
    itk::IntensityLinearTransform< TInput, TOutput > &transform)
  {
  os << "IntensityLinearTransform: " << std::endl;
  for (unsigned int i = 1; i < transform.m_FixedPoints.size(); i++){
    os << transform.m_FixedPoints[i].first << "->" << transform.m_FixedPoints[i].second;
    os << std::endl;
  }
return os;
  for (unsigned int i = 1; i < transform.m_NumSegments - 1; i++)
    {
    os << "(" << transform.m_FixedPoints[i].first << " ,"
              << transform.m_FixedPoints[i + 1].first << "]";
    os << " : " << transform.m_LineSegments[i].first << " * x + "
                << transform.m_LineSegments[i].second;
    os << std::endl;
    }
  os << "(" << (transform.m_FixedPoints.rbegin() + 1)->first << " ," << " Inf)";
  os << " : " << transform.m_LineSegments.back().first << " * x + "
              << transform.m_LineSegments.back().second;
  os << std::endl;

  return os;
  }
}

#endif
